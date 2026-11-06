#pragma once

#include <cstddef>
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace saga::game {

struct Room {
    std::string id;
    std::string path;
    std::vector<std::string> flags;
};

struct RoomLink {
    std::string id;
    std::optional<std::size_t> index;
};

struct Area {
    std::string id;
    std::vector<RoomLink> rooms;
    std::vector<std::string> flags;
};

struct Bounty {
    std::string target;
    std::size_t room{};
};

struct Catalogue {
    std::vector<Room> rooms;
    std::vector<Area> areas;
    std::vector<std::vector<std::size_t>> episodes;
    std::vector<Bounty> bounties;

    const Room* find_scene(std::string_view native_path) const;
};

Catalogue load_catalogue(const std::filesystem::path& game_archive);

}  // namespace saga::game
