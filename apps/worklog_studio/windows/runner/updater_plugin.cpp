#include "updater_plugin.h"

#include <windows.h>
#include <flutter/standard_method_codec.h>

#include "WinSparkle.h"

#include <string>

UpdaterPlugin::UpdaterPlugin(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger,
      "worklog_studio/updater",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
}

void UpdaterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "checkForUpdates") {
    win_sparkle_check_update_with_ui();
    result->Success();
  } else if (method == "checkSilently") {
    win_sparkle_check_update_without_ui();
    result->Success();
  } else if (method == "getVersion") {
    // FLUTTER_VERSION is injected at compile time by runner/CMakeLists.txt.
    result->Success(flutter::EncodableValue(std::string(FLUTTER_VERSION)));
  } else {
    result->NotImplemented();
  }
}
