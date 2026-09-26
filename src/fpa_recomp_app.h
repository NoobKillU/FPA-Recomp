// fpa_recomp - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <cstdlib>
#include <filesystem>
#include <string>
#include <vector>

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

#include <rex/rex_app.h>
#include <rex/runtime.h>

namespace {

std::filesystem::path GetExecutableDirectory() {
  std::vector<wchar_t> buffer(MAX_PATH);
  while (buffer.size() <= 32768) {
    const DWORD length = GetModuleFileNameW(
        nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length == 0) {
      break;
    }
    if (length < static_cast<DWORD>(buffer.size())) {
      return std::filesystem::path(std::wstring(buffer.data(), length))
          .parent_path();
    }
    buffer.resize(buffer.size() * 2);
  }
  return std::filesystem::current_path();
}

}  // namespace

class FpaRecompApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<FpaRecompApp>(new FpaRecompApp(ctx, "fpa_recomp",
        PPCImageConfig));
  }

  void OnPreSetup(rex::RuntimeConfig& config) override {
    config.gpu_plugin = "xenos";
  }

  void OnConfigurePaths(rex::PathConfig& paths) override {
    char* game_root = nullptr;
    size_t game_root_length = 0;
    if (::_dupenv_s(&game_root, &game_root_length, "FPA_GAME_ROOT") == 0 &&
        game_root && *game_root) {
      paths.game_data_root = game_root;
      std::free(game_root);
      return;
    }
    std::free(game_root);
    paths.game_data_root = GetExecutableDirectory();
  }

  // Other hooks can be added when behavior analysis identifies a need:
  // void OnPostInitLogging() override {}
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  // void OnPostSetup() override {}
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  // void OnShutdown() override {}
};
