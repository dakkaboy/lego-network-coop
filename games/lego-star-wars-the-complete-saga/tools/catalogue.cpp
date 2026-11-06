#include "game/catalogue.hpp"
#include "live_scene.hpp"

#include <exception>
#include <iostream>
#include <stdexcept>

namespace {

void print_flags(const std::vector<std::string>& flags) {
    for (const auto& flag : flags) {
        std::cout << '\t' << flag;
    }
    std::cout << '\n';
}

void print_catalogue(const saga::game::Catalogue& catalogue) {
    for (std::size_t episode = 0; episode < catalogue.episodes.size(); ++episode) {
        for (const auto index : catalogue.episodes[episode]) {
            std::cout << "episode\t" << episode + 1 << '\t' << catalogue.areas[index].id << '\n';
        }
    }
    for (const auto& area : catalogue.areas) {
        std::cout << "area\t" << area.id;
        print_flags(area.flags);
        for (const auto& room : area.rooms) {
            std::cout << "area_room\t" << area.id << '\t' << room.id << '\n';
        }
    }
    for (const auto& room : catalogue.rooms) {
        std::cout << "room\t" << room.id << '\t' << room.path;
        print_flags(room.flags);
    }
    for (const auto& bounty : catalogue.bounties) {
        std::cout << "bounty\t" << bounty.target << '\t' << catalogue.rooms[bounty.room].id << '\n';
    }
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
    if (argc < 2) {
        std::cerr << "Usage: saga_catalogue <GAME.DAT> [--list | --pid <PID> | native-scene-path ...]\n";
        return 2;
    }
    try {
        const auto catalogue = saga::game::load_catalogue(argv[1]);
        std::cout << "episodes=" << catalogue.episodes.size() << " areas=" << catalogue.areas.size()
                  << " rooms=" << catalogue.rooms.size() << " bounties=" << catalogue.bounties.size() << '\n';
        for (const auto& area : catalogue.areas) {
            for (const auto& room : area.rooms) {
                if (!room.index) {
                    std::cout << "Unresolved room in " << area.id << ": " << room.id << '\n';
                }
            }
        }
        bool resolved = true;
        for (int i = 2; i < argc; ++i) {
            const std::wstring_view argument(argv[i]);
            if (argument == L"--list") {
                print_catalogue(catalogue);
                continue;
            }
            std::string path;
            if (argument == L"--pid") {
                if (++i == argc) {
                    throw std::runtime_error("Missing Saga PID");
                }
                const std::wstring pid_text(argv[i]);
                if (pid_text.empty() || pid_text.find_first_not_of(L"0123456789") != std::wstring::npos) {
                    throw std::runtime_error("Invalid Saga PID");
                }
                const auto live = read_live_scene(std::stoul(pid_text));
                if (!live) {
                    std::cerr << "No active scene available\n";
                    return 3;
                }
                path = *live;
            } else {
                path = std::filesystem::path(argv[i]).string();
            }
            const auto* room = catalogue.find_scene(path);
            if (room) {
                std::cout << room->id << '\t' << room->path << '\n';
            } else {
                std::cerr << "Unknown scene: " << path << '\n';
                resolved = false;
            }
        }
        return resolved ? 0 : 1;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
