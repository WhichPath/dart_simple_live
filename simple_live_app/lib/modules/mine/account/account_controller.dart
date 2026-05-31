import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AccountController extends GetxController {
  static const _douyinHomeUrl = "https://www.douyin.com/";
  static const _douyinAppUrl = "snssdk1128://";

  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  void douyinTap() async {
    douyinLogin();
  }

  void douyinLogin() {
    Utils.showBottomSheet(
      title: "抖音账号",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Platform.isAndroid || Platform.isIOS
                  ? Icons.phone_android
                  : Icons.open_in_browser,
            ),
            title: Text(
              Platform.isAndroid || Platform.isIOS
                  ? "打开抖音 App"
                  : "浏览器登录后粘贴 Cookie",
            ),
            subtitle: Text(
              Platform.isAndroid || Platform.isIOS
                  ? "手机网页会引导下载 App；Cookie 请从电脑浏览器获取完整 Cookie 后粘贴或同步"
                  : "使用系统浏览器打开抖音，登录后回到这里粘贴完整 Cookie",
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Get.back();
              if (Platform.isAndroid || Platform.isIOS) {
                await openDouyinApp();
              } else {
                await openDouyinInBrowserThenConfigCookie();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动粘贴自己的 www.douyin.com 完整 Cookie"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doDouyinCookieConfig();
            },
          ),
          if (DouyinAccountService.instance.hasCookie.value)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("清除 Cookie"),
              subtitle: const Text("清除后恢复默认 ttwid"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Get.back();
                await clearDouyinCookie();
              },
            ),
        ],
      ),
    );
  }

  Future<void> clearDouyinCookie() async {
    if (DouyinAccountService.instance.hasCookie.value) {
      var result =
          await Utils.showAlertDialog("确定要清除自定义抖音 Cookie 吗？", title: "清除配置");
      if (result) {
        DouyinAccountService.instance.clearCookie();
        SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
      }
    }
  }

  Future<void> openDouyinInBrowserThenConfigCookie() async {
    try {
      final opened = await launchUrlString(
        _douyinHomeUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        SmartDialog.showToast("无法打开系统浏览器，请手动打开 www.douyin.com 后粘贴 Cookie");
      }
    } catch (_) {
      SmartDialog.showToast("无法打开系统浏览器，请手动打开 www.douyin.com 后粘贴 Cookie");
    }
    doDouyinCookieConfig();
  }

  Future<void> openDouyinApp() async {
    var opened = false;
    try {
      opened = await launchUrlString(
        _douyinAppUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && Platform.isAndroid) {
      try {
        opened = await launchUrlString(
          "market://details?id=com.ss.android.ugc.aweme",
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }
    if (!opened) {
      SmartDialog.showToast("无法打开抖音 App，请确认已安装");
      return;
    }
    SmartDialog.showToast("已打开抖音 App；搜索所需 Cookie 仍需粘贴完整网页登录 Cookie");
  }

  void doDouyinCookieConfig() {
    // 兼容旧版只保存 ttwid 的配置。
    var savedCookie = DouyinAccountService.instance.cookie;
    var displayText = savedCookie;
    if (savedCookie.startsWith('ttwid=') && !savedCookie.contains(";")) {
      displayText = savedCookie.substring(6);
    }
    var controller = TextEditingController(text: displayText);

    Get.dialog(
      AlertDialog(
        title: const Text("配置抖音 Cookie"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "默认内置 ttwid 可用于播放；房间名/主播名搜索被要求登录时，不能只填 ttwid，需要粘贴登录后的完整 www.douyin.com Cookie。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              const Text(
                "电脑端获取方式：F12 打开开发者工具，在 Network 里点 www.douyin.com/aweme/v1/web/live/search/ 或其他 www.douyin.com 请求，复制 Request Headers 里的 Cookie 整行。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "搜索请粘贴完整 Cookie；只填 ttwid 只能作为播放兜底",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  var defaultValue = DouyinSite.kDefaultCookie;
                  if (defaultValue.startsWith('ttwid=')) {
                    defaultValue = defaultValue.substring(6);
                  }
                  controller.text = defaultValue;
                },
                icon: const Icon(Icons.restore),
                label: const Text("恢复默认 ttwid"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              var input = controller.text.trim();
              Get.back();
              if (input.isEmpty) {
                DouyinAccountService.instance.clearCookie();
                SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
              } else {
                var cookie = _normalizeDouyinCookieInput(input);
                DouyinAccountService.instance.setCookie(cookie);
                if (_isOnlyDouyinTtwid(cookie)) {
                  SmartDialog.showToast("已保存 ttwid；搜索仍可能需要完整登录 Cookie");
                } else {
                  SmartDialog.showToast("抖音 Cookie 已保存");
                }
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }

  bool _isOnlyDouyinTtwid(String cookie) {
    final normalized = cookie.trim().toLowerCase();
    return normalized.startsWith("ttwid=") && !normalized.contains(";");
  }

  String _normalizeDouyinCookieInput(String input) {
    var cookie = input.trim();
    if (cookie.toLowerCase().startsWith("cookie:")) {
      cookie = cookie.substring(cookie.indexOf(":") + 1).trim();
    }
    if (!cookie.contains("=")) {
      cookie = 'ttwid=$cookie';
    }
    return cookie;
  }
}
