//
//  AppDelegate.swift
//  osMon
//
//  Created by Hiroshi Horie on 2021/02/20.
//

import Cocoa
import Foundation
import IOKit.ps
import AudioToolbox

func _onPowerSourceChanged(context: UnsafeMutableRawPointer?) {
  let _self = Unmanaged<AppDelegate>.fromOpaque(context!).takeUnretainedValue()
  _self.checkIsOnACPower()
}

class AppDelegate: NSObject, NSApplicationDelegate {
  
  //  var statusBarItem: NSStatusItem!
  var _powerNotificationLoopSource: CFRunLoopSource?
  var _timer: Timer?

  func applicationDidFinishLaunching(_ aNotification: Notification) {
 
    //
    //    statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
    //
    //    if let button = statusBarItem.button {
    //      button.title = "osMon"
    //      //      button.menu =
    //      //        createMenu()
    //      let menu = NSMenu()
    //      menu.addItem(NSMenuItem(title: "Quit", action: nil, keyEquivalent: "Q"))
    //      //    return menu
    //      statusBarItem.menu = menu
    //      //      NSLog("@%", button.menu ?? nil)
    //      // button.image = NSImage(named: "Icon")
    //      // button.action = #selector(togglePopover(_:))
    //
    //    }
    
    
    let selfOpaque = Unmanaged<AppDelegate>.passUnretained(self).toOpaque()

    _powerNotificationLoopSource = IOPSCreateLimitedPowerNotification(
      _onPowerSourceChanged,
      UnsafeMutableRawPointer(selfOpaque)
    ).takeRetainedValue() as CFRunLoopSource
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), _powerNotificationLoopSource, CFRunLoopMode.defaultMode)
    
    checkIsOnACPower()
  }
  
  func applicationWillTerminate(_ aNotification: Notification) {
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _powerNotificationLoopSource, CFRunLoopMode.defaultMode)
    _timer?.invalidate()
    _timer = nil
  }
  
  func getBatteryPercentage() -> Int {
    // Returns battery charge percentage (0-100)
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
    for source in sources {
      if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
        if description["Type"] as? String == kIOPSInternalBatteryType {
          return description[kIOPSCurrentCapacityKey] as? Int ?? 0
        }
      }
    }
    return 0
  }
  
  func isOnACPower() -> Bool {
    
    // Take a snapshot of all the power source info
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let powerSource = IOPSGetProvidingPowerSourceType(snapshot).takeRetainedValue()
    return powerSource as String == kIOPSACPowerValue
    //      print(powerSource)
    
    //      // Pull out a list of power sources
    //      let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
    //
    //      // For each power source...
    //      for srouce in sources {
    //        // Fetch the information for a given power source out of our snapshot
    //        let info = IOPSGetPowerSourceDescription(snapshot, srouce).takeUnretainedValue() as! [String: AnyObject]
    //
    //        // Pull out the name and capacity
    //        if let name = info[kIOPSNameKey] as? String,
    //           let capacity = info[kIOPSCurrentCapacityKey] as? Int,
    //           let max = info[kIOPSMaxCapacityKey] as? Int,
    //           let isCharging = info[kIOPSIsChargingKey] as? Bool
    ////           ,
    ////           let s = info[kIOPSACPowerValue] as? Bool
    //        {
    //          print("\(name): \(capacity) of \(max) : charging:\(isCharging), safe")
    //        }
    //      }
  }
  
  
  func setVolume(_ volume: Float) {

    var setVolume = Float32(volume)
    var defaultOutputDeviceId: AudioObjectID = 0
    
    var propertyAddress_defaultOutputDevice = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
    )
    
    var propertyAddress_volume = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMaster
    )
    
    var propertyAddress_mute = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMaster
    )
    
    var audioObjectIdSize = UInt32(MemoryLayout<AudioObjectID>.size)
    
    AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &propertyAddress_defaultOutputDevice,
      0,
      nil,
      &audioObjectIdSize,
      &defaultOutputDeviceId)
    
    var setMute : UInt32 = 0;
    
    AudioObjectSetPropertyData(
      defaultOutputDeviceId,
      &propertyAddress_mute,
      0,
      nil,
      UInt32( MemoryLayout<UInt32>.size),
      &setMute)
    
    AudioObjectSetPropertyData(
      defaultOutputDeviceId,
      &propertyAddress_volume,
      0,
      nil,
      UInt32(MemoryLayout<Float32>.size),
      &setVolume)
  }
  
  func checkIsOnACPower() {
    let isAc = isOnACPower()
    print("isOnACPower: \(isAc)")
    
    if isOnACPower() {
      _timer?.invalidate()
      _timer = nil
    } else {
      _timer?.invalidate()
      _timer = Timer.scheduledTimer(timeInterval: 2.0,
                                    target: self,
                                    selector: #selector(onTimer),
                                    userInfo: nil,
                                    repeats: true)
    }
  }
  
  @objc func onTimer() {
    setVolume(0.8)
    NSSound.glass?.play()
    AudioServicesPlayAlertSound(kSystemSoundID_FlashScreen)
  }
}

