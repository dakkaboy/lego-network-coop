#include "catalogue.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <fstream>
#include <span>
#include <stdexcept>

namespace saga::game {
namespace {

using Bytes = std::vector<char>;
using Tokens = std::vector<std::string_view>;
using Block = std::vector<Tokens>;

std::uint32_t word(std::span<const char> bytes, std::size_t at) {
    if (at > bytes.size() || bytes.size() - at < 4) {
        throw std::runtime_error("Truncated GAME.DAT index");
    }
    std::uint32_t value = 0;
    for (std::size_t i = 0; i < 4; ++i) {
        value |= static_cast<std::uint32_t>(static_cast<unsigned char>(bytes[at + i])) << (8 * i);
    }
    return value;
}

void read(std::ifstream& file, std::uint64_t offset, std::span<char> bytes) {
    file.seekg(static_cast<std::streamoff>(offset));
    if (!file.read(bytes.data(), static_cast<std::streamsize>(bytes.size()))) {
        throw std::runtime_error("Could not read GAME.DAT");
    }
}

std::uint32_t path_hash(std::string_view uppercase_path) {
    std::uint32_t hash = 0x811c9dc5;
    for (const char c : uppercase_path) {
        hash = (hash ^ static_cast<unsigned char>(c)) * 0x199933;
    }
    return hash;
}

class Archive {
public:
    explicit Archive(const std::filesystem::path& path) : file_(path, std::ios::binary | std::ios::ate) {
        const auto file_size = file_.tellg();
        if (file_size < 8) {
            throw std::runtime_error("Could not open GAME.DAT");
        }
        std::array<char, 8> header{};
        read(file_, 0, header);
        index_at_ = word(header, 0);
        const auto index_size = word(header, 4);
        if (index_at_ < 8 || index_size < 16 || index_size > 16 * 1024 * 1024
            || index_at_ + index_size > static_cast<std::uint64_t>(file_size)) {
            throw std::runtime_error("Invalid GAME.DAT index bounds");
        }
        index_.resize(index_size);
        read(file_, index_at_, index_);
        if (word(index_, 0) != 0xfffffffd) {
            throw std::runtime_error("Unsupported GAME.DAT index version");
        }
        count_ = word(index_, 4);
        if (count_ == 0 || count_ > (index_.size() - 8) / 16) {
            throw std::runtime_error("Invalid GAME.DAT entry count");
        }
        const auto names_at = 8 + count_ * 16;
        const auto names_count = word(index_, names_at);
        if (names_count > (index_.size() - names_at - 4) / 8) {
            throw std::runtime_error("Invalid GAME.DAT name count");
        }
        const auto strings_at = names_at + 4 + names_count * 8;
        const auto strings_size = word(index_, strings_at);
        if (strings_size > index_.size() - strings_at - 4) {
            throw std::runtime_error("Invalid GAME.DAT name table");
        }
        hashes_at_ = strings_at + 4 + strings_size;
        if (count_ > (index_.size() - hashes_at_) / 4) {
            throw std::runtime_error("Truncated GAME.DAT path hashes");
        }
    }

    std::string text(std::string_view path) {
        const auto hash = path_hash(path);
        std::size_t entry = count_;
        for (std::size_t i = 0; i < count_; ++i) {
            if (word(index_, hashes_at_ + 4 * i) == hash) {
                if (entry != count_) {
                    throw std::runtime_error("Ambiguous GAME.DAT catalogue path");
                }
                entry = i;
            }
        }
        if (entry == count_) {
            throw std::runtime_error("Missing GAME.DAT catalogue entry");
        }
        const auto at = 8 + 16 * entry;
        const auto packed_size = word(index_, at + 4);
        const auto size = word(index_, at + 8);
        const auto flags = word(index_, at + 12);
        const auto offset = (static_cast<std::uint64_t>(word(index_, at)) << 8)
            | ((flags >> 8) & 0xff);
        if ((flags & 0xff) != 0 || size != packed_size || size == 0 || size > 1024 * 1024
            || offset < 8 || offset + size > index_at_) {
            throw std::runtime_error("Invalid GAME.DAT catalogue payload");
        }
        std::string result(size, '\0');
        read(file_, offset, result);
        return result;
    }

private:
    std::ifstream file_;
    Bytes index_;
    std::uint64_t index_at_{};
    std::size_t count_{};
    std::size_t hashes_at_{};
};

std::string normalized(std::string_view value) {
    std::string result(value);
    for (auto& c : result) {
        if (c >= 'A' && c <= 'Z') {
            c = static_cast<char>(c + ('a' - 'A'));
        } else if (c == '/') {
            c = '\\';
        }
    }
    return result;
}

Tokens tokenize(std::string_view line) {
    constexpr std::string_view whitespace = " \t\r";
    if (const auto last = line.find_last_not_of(whitespace); last != std::string_view::npos) {
        line = line.substr(0, last + 1);
    }
    Tokens tokens;
    while (!line.empty()) {
        const auto first = line.find_first_not_of(whitespace);
        if (first == std::string_view::npos) {
            break;
        }
        line.remove_prefix(first);
        if (line.starts_with("//") || line.starts_with(';')) {
            break;
        }
        if (line.front() == '"') {
            line.remove_prefix(1);
            const auto end = line.find('"');
            tokens.push_back(line.substr(0, end));
            line.remove_prefix(end == std::string_view::npos ? line.size() : end + 1);
        } else {
            const auto end = line.find_first_of(whitespace);
            tokens.push_back(line.substr(0, end));
            line.remove_prefix(end == std::string_view::npos ? line.size() : end);
        }
    }
    return tokens;
}

template <class Consume>
void lines(std::string_view text, Consume consume) {
    while (!text.empty()) {
        const auto end = text.find('\n');
        auto tokens = tokenize(text.substr(0, end));
        if (!tokens.empty()) {
            consume(std::move(tokens));
        }
        text.remove_prefix(end == std::string_view::npos ? text.size() : end + 1);
    }
}

template <class Consume>
void blocks(std::string_view text, std::string_view start, std::string_view end, Consume consume) {
    Block block;
    bool open = false;
    lines(text, [&](Tokens tokens) {
        const auto key = normalized(tokens.front());
        if (key == start && !open) {
            open = true;
        } else if (key == end && open) {
            consume(block);
            block.clear();
            open = false;
        } else if (open && key != start) {
            block.push_back(std::move(tokens));
        } else if (key == start || key == end) {
            throw std::runtime_error("Unexpected GAME.DAT catalogue line");
        }
    });
    if (open) {
        throw std::runtime_error("Unterminated GAME.DAT catalogue block");
    }
}

std::string field(const Block& block, std::string_view name) {
    for (const auto& row : block) {
        if (row.size() == 2 && normalized(row.front()) == name && !row[1].empty()) {
            return normalized(row[1]);
        }
    }
    throw std::runtime_error("Missing GAME.DAT catalogue field");
}

std::vector<std::string> flags(const Block& block) {
    std::vector<std::string> result;
    for (const auto& row : block) {
        if (row.size() == 1) {
            result.push_back(normalized(row.front()));
        }
    }
    return result;
}

template <class Record>
std::optional<std::size_t> index_of(const std::vector<Record>& records, std::string_view id) {
    const auto found = std::ranges::find(records, normalized(id), &Record::id);
    if (found == records.end()) {
        return std::nullopt;
    }
    return static_cast<std::size_t>(found - records.begin());
}

template <class Record>
std::size_t require_index(const std::vector<Record>& records, std::string_view id) {
    const auto index = index_of(records, id);
    if (!index) {
        throw std::runtime_error("Unresolved GAME.DAT catalogue reference: " + std::string(id));
    }
    return *index;
}

}  // namespace

const Room* Catalogue::find_scene(std::string_view native_path) const {
    const auto path = normalized(native_path);
    const auto found = std::ranges::find(rooms, path, &Room::path);
    return found == rooms.end() ? nullptr : &*found;
}

Catalogue load_catalogue(const std::filesystem::path& game_archive) {
    Archive archive(game_archive);
    Catalogue result;
    blocks(archive.text("LEVELS\\LEVELS.TXT"), "level_start", "level_end", [&](const Block& block) {
        auto id = field(block, "file");
        if (index_of(result.rooms, id)) {
            throw std::runtime_error("Duplicate GAME.DAT room ID: " + id);
        }
        auto path = "levels\\" + field(block, "dir") + "\\" + id;
        result.rooms.push_back({std::move(id), std::move(path), flags(block)});
    });
    blocks(archive.text("LEVELS\\AREAS.TXT"), "area_start", "area_end", [&](const Block& block) {
        Area area{.id = field(block, "file"), .rooms = {}, .flags = flags(block)};
        if (index_of(result.areas, area.id)) {
            throw std::runtime_error("Duplicate GAME.DAT area ID: " + area.id);
        }
        for (const auto& row : block) {
            if (row.size() == 2 && normalized(row.front()) == "level") {
                area.rooms.push_back({normalized(row[1]), index_of(result.rooms, row[1])});
            }
        }
        result.areas.push_back(std::move(area));
    });
    blocks(archive.text("LEVELS\\EPISODES.TXT"), "episode_start", "episode_end", [&](const Block& block) {
        std::vector<std::size_t> episode;
        for (const auto& row : block) {
            if (row.size() == 2 && normalized(row.front()) == "area") {
                episode.push_back(require_index(result.areas, row[1]));
            }
        }
        result.episodes.push_back(std::move(episode));
    });
    lines(archive.text("LEVELS\\MISSIONS.TXT"), [&](const Tokens& row) {
        if (normalized(row.front()) == "mission") {
            if (row.size() < 5 || normalized(row[1]) != "find" || normalized(row[3]) != "in_level") {
                throw std::runtime_error("Unsupported bounty catalogue entry");
            }
            result.bounties.push_back({normalized(row[2]), require_index(result.rooms, row[4])});
        }
    });
    if (result.rooms.empty() || result.areas.empty() || result.episodes.empty()) {
        throw std::runtime_error("GAME.DAT catalogue is empty");
    }
    return result;
}

}  // namespace saga::game
