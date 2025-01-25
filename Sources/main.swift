// The Swift Programming Language
// https://docs.swift.org/swift-book

import Cocoa
import IOKit
import IOKit.pwr_mgt
import IOKit.graphics
import ServiceManagement
import LaunchAtLogin

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var isPreventingSleep = false
    private var assertionID: IOPMAssertionID = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置状态栏按钮的样式
        if #available(macOS 10.14, *) {
            if let button = statusItem.button {
                button.appearance = NSAppearance(named: .darkAqua)
            }
        }
        
        updateStatusBarIcon(isActive: false) // 初始状态为灰色
        
        // 创建菜单
        let menu = NSMenu()
        
        // 添加开关选项
        let toggleItem = NSMenuItem(title: "防止系统睡眠", action: #selector(toggleSleep), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = .on  // 默认设置为开启状态
        menu.addItem(toggleItem)
        
        // 添加关闭显示器选项
        let displayOffItem = NSMenuItem(title: "关闭显示器", action: #selector(turnOffDisplay), keyEquivalent: "")
        displayOffItem.target = self
        menu.addItem(displayOffItem)
        
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 添加开机启动选项
        let launchAtLoginItem = NSMenuItem(title: "开机启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 添加退出选项
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        // 设置菜单
        statusItem.menu = menu
        
        // 启动时自动开启防止睡眠
        enablePreventSleep()
    }
    
    private func updateStatusBarIcon(isActive: Bool) {
        guard let button = statusItem.button else { return }
        
        // 加载SVG图标
        if let svgPath = Bundle.module.path(forResource: "icon", ofType: "svg"),
           let image = NSImage(contentsOfFile: svgPath) {
            image.isTemplate = true // 使图标支持系统颜色
            image.size = NSSize(width: 18, height: 18) // 设置合适的大小
            button.image = image
            button.alphaValue = isActive ? 1.0 : 0.5
        } else {
            // 如果SVG加载失败，使用文字图标作为后备
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: isActive ? NSColor.white : NSColor(white: 1.0, alpha: 0.5)
            ]
            button.attributedTitle = NSAttributedString(string: "💡", attributes: attributes)
        }
    }
    
    // 新增方法：启用防止睡眠
    private func enablePreventSleep() {
        isPreventingSleep = true
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "NoSleep is preventing system sleep" as CFString,
            &assertionID)
        
        if result == kIOReturnSuccess {
            print("防止系统睡眠已开启")
            updateStatusBarIcon(isActive: true)
        } else {
            print("无法开启防止睡眠：错误代码 \(result)")
            isPreventingSleep = false
            if let item = statusItem.menu?.items.first {
                item.state = .off
            }
            updateStatusBarIcon(isActive: false)
        }
    }
    
    @objc func toggleSleep(_ sender: NSMenuItem) {
        isPreventingSleep.toggle()
        sender.state = isPreventingSleep ? .on : .off
        
        if isPreventingSleep {
            // 开启防止系统睡眠，但允许显示器睡眠
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NoSleep is preventing system sleep" as CFString,
                &assertionID)
            
            if result == kIOReturnSuccess {
                print("防止系统睡眠已开启")
            } else {
                print("无法开启防止睡眠：错误代码 \(result)")
                isPreventingSleep = false
                sender.state = .off
            }
        } else {
            // 关闭防止睡眠
            if assertionID != 0 {
                let result = IOPMAssertionRelease(assertionID)
                if result == kIOReturnSuccess {
                    print("防止睡眠已关闭")
                    assertionID = 0
                } else {
                    print("无法关闭防止睡眠：错误代码 \(result)")
                }
            }
        }
        
        updateStatusBarIcon(isActive: isPreventingSleep)
    }
    
    @objc func turnOffDisplay() {
        // 使用 IOKit 关闭显示器
        _ = CGMainDisplayID()
        
        // 使用 IORegistryEntry 来关闭显示器
        _ = IORegistryEntryCreateCFProperty(
            IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayWrangler")),
            "IORequestIdle" as CFString,
            kCFAllocatorDefault,
            0
        )
        
        // 发送关闭显示器的命令
        let board = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler")
        if board != 0 {
            IORegistryEntrySetCFProperty(board, "IORequestIdle" as CFString, true as CFTypeRef)
            IOObjectRelease(board)
        }
    }
    
    // 检查是否已启用开机启动
    private func isLaunchAtLoginEnabled() -> Bool {
        let launchAgentPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.example.NoSleep.plist")
        return FileManager.default.fileExists(atPath: launchAgentPath.path)
    }
    
    // 切换开机启动状态
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let fileManager = FileManager.default
        let launchAgentsDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("com.example.NoSleep.plist")
        
        if isLaunchAtLoginEnabled() {
            // 删除启动项
            do {
                try fileManager.removeItem(at: plistPath)
                sender.state = .off
                print("已删除开机启动项")
            } catch {
                print("删除开机启动项失败: \(error)")
                let alert = NSAlert()
                alert.messageText = "无法删除开机启动项"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        } else {
            // 创建启动项
            do {
                // 确保 LaunchAgents 目录存在
                if !fileManager.fileExists(atPath: launchAgentsDir.path) {
                    try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
                }
                
                // 创建 plist 内容
                let plistContent = """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <dict>
                    <key>Label</key>
                    <string>com.example.NoSleep</string>
                    <key>Program</key>
                    <string>/Applications/NoSleep.app/Contents/MacOS/NoSleep</string>
                    <key>RunAtLoad</key>
                    <true/>
                    <key>KeepAlive</key>
                    <false/>
                    <key>ProcessType</key>
                    <string>Interactive</string>
                    <key>LSBackgroundOnly</key>
                    <false/>
                    <key>StandardErrorPath</key>
                    <string>/tmp/com.example.NoSleep.err</string>
                    <key>StandardOutPath</key>
                    <string>/tmp/com.example.NoSleep.out</string>
                </dict>
                </plist>
                """
                
                try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
                sender.state = .on
                print("已创建开机启动项")
                
                // 立即加载启动项
                let task = Process()
                task.launchPath = "/bin/launchctl"
                task.arguments = ["load", plistPath.path]
                task.launch()
                task.waitUntilExit()
                
            } catch {
                print("创建开机启动项失败: \(error)")
                let alert = NSAlert()
                alert.messageText = "无法创建开机启动项"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        }
    }
    
    // 确保在应用退出时释放断言
    func applicationWillTerminate(_ notification: Notification) {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
        }
    }
}

// 创建应用实例并运行
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
