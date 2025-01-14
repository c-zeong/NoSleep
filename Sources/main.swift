// The Swift Programming Language
// https://docs.swift.org/swift-book

import Cocoa
import IOKit.pwr_mgt

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
        let toggleItem = NSMenuItem(title: "防止睡眠", action: #selector(toggleSleep), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 添加退出选项
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        // 设置菜单
        statusItem.menu = menu
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
    
    @objc func toggleSleep(_ sender: NSMenuItem) {
        isPreventingSleep.toggle()
        sender.state = isPreventingSleep ? .on : .off
        
        if isPreventingSleep {
            // 开启防止睡眠
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,  // 防止显示器睡眠
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NoSleep is preventing sleep" as CFString,
                &assertionID)
            
            if result == kIOReturnSuccess {
                print("防止睡眠已开启")
            } else {
                print("无法开启防止睡眠：错误代码 \(result)")
                // 如果失败，恢复开关状态
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
        
        // 更新图标颜色
        updateStatusBarIcon(isActive: isPreventingSleep)
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
