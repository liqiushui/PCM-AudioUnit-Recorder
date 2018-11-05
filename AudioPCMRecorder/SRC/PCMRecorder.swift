//
//  PCMRecorder.swift
//  AudioPCMRecorder
//
//  Created by lunli on 2018/11/5.
//  Copyright © 2018年 lunli. All rights reserved.
//

import UIKit
import AudioUnit
import CoreMedia

//部分参考：https://github.com/preble/SwiftToneAudioUnit/blob/master/SwiftToneAudioUnit/AudioUnit.swift

class PCMRecorder: NSObject {
    
    private var auduiUnit: AudioComponentInstance? = nil
    let frequency = 44100
    @objc public var callback:((CMSampleBuffer) -> (Void))?
    
    override init() {
        super.init()
        setup()
    }
    
    deinit {
        stop()
    }
    
    func start() {
        var status: OSStatus
        status = AudioUnitInitialize(auduiUnit!)
        assert(status == noErr)
        status = AudioOutputUnitStart(auduiUnit!)
        assert(status == noErr)

    }
    
    func stop() {
        AudioOutputUnitStop(auduiUnit!)
        AudioUnitUninitialize(auduiUnit!)
    }
    
    
    func setup() -> Void {
        
        
        let componentSubtype: OSType = kAudioUnitSubType_RemoteIO
        var defaultOutputDescription = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                                 componentSubType: componentSubtype,
                                                                 componentManufacturer: kAudioUnitManufacturer_Apple,
                                                                 componentFlags: 0,
                                                                 componentFlagsMask: 0)
        let defaultOutput = AudioComponentFindNext(nil, &defaultOutputDescription)
        var err: OSStatus
        // Create a new instance of it in the form of our audio unit:
        err = AudioComponentInstanceNew(defaultOutput!, &auduiUnit)
        assert(err == noErr, "AudioComponentInstanceNew failed")
        
        // Set the render callback as the input for our audio unit:
        var renderCallbackStruct = AURenderCallbackStruct(inputProc: renderCallback ,
                                                          inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        err = AudioUnitSetProperty(auduiUnit!,
                                   kAudioUnitProperty_SetRenderCallback,
                                   kAudioUnitScope_Input,
                                   0,
                                   &renderCallbackStruct,
                                   UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        assert(err == noErr, "AudioUnitSetProperty SetRenderCallback failed")
        
        
        // Set the stream format for the audio unit. That is, the format of the data that our render callback will provide.
        var streamFormat = outAudioFormate()
        
        err = AudioUnitSetProperty(auduiUnit!,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &streamFormat,
                                   UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        assert(err == noErr, "AudioUnitSetProperty StreamFormat failed")
    }
    
    func outAudioFormate() -> AudioStreamBasicDescription {
        let  streamFormat = AudioStreamBasicDescription(mSampleRate: Float64(frequency),
                                                        mFormatID: kAudioFormatLinearPCM,
                                                        mFormatFlags: kAudioFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked,
                                                        mBytesPerPacket: 2 /*four bytes per float*/,
                                                        mFramesPerPacket: 1,
                                                        mBytesPerFrame: 2,
                                                        mChannelsPerFrame: 1,
                                                        mBitsPerChannel: 16,
                                                        mReserved: 0)
        
        return streamFormat
    }

}

private func renderCallback(inRefCon: UnsafeMutableRawPointer,
                            ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                            inTimeStamp: UnsafePointer<AudioTimeStamp>,
                            inBusNumber: UInt32,
                            inNumberFrames: UInt32,
                            ioData: UnsafeMutablePointer<AudioBufferList>? ) -> OSStatus {
    
    
    let recorder = Unmanaged<PCMRecorder>.fromOpaque(inRefCon).takeUnretainedValue()
    var monoStreamFormat:AudioStreamBasicDescription = recorder.outAudioFormate()
    var formateDes:CMFormatDescription? = nil
    var status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                asbd: &monoStreamFormat,
                                                layoutSize: 0,
                                                layout: nil,
                                                magicCookieSize: 0,
                                                magicCookie: nil,
                                                extensions: nil, formatDescriptionOut: &formateDes)
    
    assert(status == noErr, "CMAudioFormatDescriptionCreate failed")
    let p = UnsafeMutablePointer<mach_timebase_info_data_t>.allocate(capacity: 1)
    mach_timebase_info(p)
    
    let timeNS:UInt64 = UInt64(Double(inTimeStamp.pointee.mHostTime) * (Double)(p.pointee.numer / p.pointee.denom))
    var time:CMSampleTimingInfo = CMSampleTimingInfo.init(duration: CMTime.init(value: 1, timescale: CMTimeScale(recorder.frequency)),
                                                          presentationTimeStamp: CMTime.init(value: CMTimeValue(timeNS), timescale: 1000000000),
                                                          decodeTimeStamp: CMTime.invalid)
    
    var sampleBuffer:CMSampleBuffer?
        
    status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                            dataBuffer: nil,
                                            dataReady: false,
                                            makeDataReadyCallback: nil,
                                            refcon: nil,
                                            formatDescription: formateDes,
                                            sampleCount: CMItemCount(inNumberFrames),
                                            sampleTimingEntryCount: 1,
                                            sampleTimingArray: &time,
                                            sampleSizeEntryCount: 0,
                                            sampleSizeArray: nil,
                                            sampleBufferOut: &sampleBuffer)
    
    assert(status == noErr, "CMSampleBufferCreate failed")

    status = CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer!,
                                                            blockBufferAllocator: kCFAllocatorDefault,
                                                            blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                            flags: 0,
                                                            bufferList:ioData!)
    
    assert(status == noErr, "CMSampleBufferSetDataBufferFromAudioBufferList failed")
    
    if let callback:((CMSampleBuffer)->(Void)) = recorder.callback {
        callback(sampleBuffer!)
    }

    print("pcm call back")
    return noErr
}
