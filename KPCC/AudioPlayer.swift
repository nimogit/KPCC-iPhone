//
//  AudioPlayer.swift
//  KPCC
//
//  Created by Eric Richardson on 9/2/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

import Foundation
import AVFoundation
import MobileCoreServices

//-----------

public struct AudioPlayerObserver<T> {
    var observers: [(T) -> Void] = []
    var once: [(T) -> Void] = []

    public mutating func addObserver(o:(T) -> Void) {
        observers.append(o)
    }

    public mutating func once(o:(T) -> Void) {
        once.append(o)
    }

    mutating func notify(obj:T) {
        for o in observers {
            o(obj)
        }

        for o in once {
            o(obj)
        }

        once = []
    }

    private mutating func clear() -> Void {
        observers = []
        once = []
    }
}

//----------

@objc public class AudioPlayer: NSObject {
    @objc public enum AudioNetworkStatus:Int {
        case Unknown = 0, NotReachable = 1, WIFI = 2, Cellular = 3

        func toString() -> String {
            let s = ["Unknown","No Connection","WIFI","Cellular"];
            return s[self.rawValue]
        }
    }

    //----------

    @objc public class AudioEvent: NSObject {
        public var message:String
        public var time:NSDate

        init(message:String) {
            self.message = message
            self.time = NSDate()
        }
    }

    //----------

    @objc public class StreamDates: NSObject {
        var creationDate: NSDate?
        var curDate:    NSDate?
        var minDate:    NSDate?
        var maxDate:    NSDate?
        var buffered:   Double?
        var curTime:    CMTime?
        var duration:   CMTime?

        convenience init(curTime:CMTime,duration:CMTime) {
            self.init(curDate:nil,minDate:nil,maxDate:nil,buffered:nil,curTime:curTime,duration:duration)
        }

        convenience init(curDate:NSDate,minDate:NSDate?,maxDate:NSDate?,buffered:Double?) {
            self.init(curDate:curDate,minDate:minDate,maxDate:maxDate,buffered:buffered,curTime:nil,duration:nil)
        }

        init(curDate:NSDate?,minDate:NSDate?,maxDate:NSDate?,buffered:Double?,curTime:CMTime?,duration:CMTime?) {
            self.curDate = curDate
            self.minDate = minDate
            self.maxDate = maxDate
            self.buffered = buffered
            self.curTime = curTime
            self.duration = duration

            self.creationDate = NSDate()
        }

        func hasDates() -> Bool {
            if self.curDate != nil {
                return true
            } else {
                return false
            }
        }

        func hasBufferDates() -> Bool {
            if self.minDate != nil && self.maxDate != nil {
                return true
            } else {
                return false
            }
        }

        func percentToDate(percent:Float64) -> NSDate? {
            if minDate == nil || maxDate == nil {
                return nil
            }

            let duration:Double = maxDate!.timeIntervalSince1970 - minDate!.timeIntervalSince1970
            let seconds:Double = duration * percent

            return minDate!.dateByAddingTimeInterval(seconds)
        }

        func curTimeV() -> NSValue? {
            if self.curTime != nil {
                return NSValue(CMTime: self.curTime!)
            } else {
                return nil
            }
        }
    }

    //----------

    public typealias finishCallback = (Bool) -> Void

    //----------

    let _player: AVPlayer
    let observer: AVObserver

    var playing: Bool

    var _dateFormat: NSDateFormatter

    private var _lastDates: StreamDates?
    var currentDates: StreamDates?
    var liveDate: NSDate?

    private var _timeObserver: AnyObject?

    private var _playerItem: AVPlayerItem?

    //----------

    public var oTime        = AudioPlayerObserver<StreamDates>()
//    public var oShow        = AudioPlayerObserver<Schedule.ScheduleInstance?>()
    public var oStatus      = AudioPlayerObserver<AudioStatus>()
    public var oAccessLog   = AudioPlayerObserver<AVPlayerItemAccessLogEvent>()
    public var oErrorLog    = AudioPlayerObserver<AVPlayerItemErrorLogEvent>()
    public var oEventLog    = AudioPlayerObserver<AudioEvent>()
    public var oNetwork     = AudioPlayerObserver<AudioNetworkStatus>()

//    var _currentShow: Schedule.ScheduleInstance? = nil
//    var _checkingDate: NSDate?

    var _sessionId:String?

    var prevStatus: AudioStatus = AudioStatus.New
    var status: AudioStatus = AudioStatus.New

    var _wasInterrupted:Bool = false

    var _interactionIdx:Int = 0

    // Configurable Settings
    public var seekTolerance:Int = 5
    public var reduceBandwidthOnCellular:Bool = true

    let _reachability = SReachability.reachabilityForInternetConnection()
    var _networkStatus: AudioNetworkStatus = .Unknown

    //var _sessions:AudioSessionTracker? = nil

    var volume:Float {
        get {
            return self._player.volume
        }

        set {
            self._player.volume = newValue
        }
    }

    //----------

    convenience init(url:NSURL) {
        self.init(url: url,hiResTick: false)
    }

    init(url:NSURL,hiResTick:Bool = false) {
        self.playing = false

        self._dateFormat = NSDateFormatter()
        self._dateFormat.dateFormat = "hh:mm:ss a"

        self._player = AVPlayer.init(URL: url)
        self.observer = AVObserver(player:self._player)

        super.init()

        self._player.addObserver(self, forKeyPath: "currentItem", options: [ .New, .Initial ], context: nil)

        // set up an observer for player / item status
        self.observer.setCallback() { status,msg,obj in
            self._handleObservation(status, msg:msg, obj:obj)
        }

        // ios9 adds a feature to limit paused buffering
        if #available(iOS 9.0, *) {
            self._player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        }

        self._setStatus(.New)

        self._getReadyPlayer() {cold in
            // observe time every second
            let tick = hiResTick ? CMTimeMake(1,10) : CMTimeMake(1,1)

            self._timeObserver = self._player.addPeriodicTimeObserverForInterval(tick, queue: nil,
                usingBlock: {(time:CMTime) in
                    if self.status == .Seeking {
                        // we don't want to update anything mid-seek
                        return
                    }

                    self._computeStreamDates()

                    // tick liveDate one second
                    if self.liveDate != nil {
                        self.liveDate = self.liveDate?.dateByAddingTimeInterval(1.0)
                    }
            })
        }

        // -- watch for Reachability -- //

        self._reachability?.whenReachable = { r in
            self.setNetworkStatus()
        }

        self._reachability?.whenUnreachable = { r in
            self.setNetworkStatus()
        }

        self._reachability?.startNotifier()

        // and a check right now...
        self.setNetworkStatus()

        // should we be limiting bandwidth?
            if self.reduceBandwidthOnCellular && self._networkStatus == .Cellular {
                if self._player.currentItem != nil {
                    self._emitEvent("Turning on bandwidth limiter for new player")
                    self._player.currentItem!.preferredPeakBitRate = 1000
                }
            }

        // -- set up bandwidth limiter -- //
            self.oNetwork.addObserver() { s in
                if self.reduceBandwidthOnCellular {
                    if self._player.currentItem != nil {
                        switch s {
                        case .Cellular:
                            // turn limit on
                            self._emitEvent("Limiting bandwidth on cellular.")
                            self._player.currentItem!.preferredPeakBitRate = 1000
                        case .WIFI:
                            // turn limit off
                            self._emitEvent("Turning off bandwidth limit.")
                            self._player.currentItem!.preferredPeakBitRate = 0
                        default:
                            // don't make changes
                            true
                        }
                    }
                }
            }

        // -- watch for non-sensical dates -- //
        self.oTime.addObserver() { dates in
            // at times, AVPlayer seems to lose its mind and jump us to the 
            // beginning of the rewind buffer while not updating currentDate
            // or currentTime. We want to detect that and flag it, so that 
            // AudioManager can abort and set up a new player.

            // only applies to live items
            if !dates.hasDates() {
                return
            }

            if self._lastDates != nil && self._lastDates!.hasDates() && dates.hasBufferDates() && self._lastDates!.hasBufferDates() {
                // did our minDate jump unexpectedly?
                let minDiff = dates.minDate!.timeIntervalSinceReferenceDate - self._lastDates!.minDate!.timeIntervalSinceReferenceDate
                let createDiff = dates.creationDate!.timeIntervalSinceReferenceDate - self._lastDates!.creationDate!.timeIntervalSinceReferenceDate

                // we're looking for substantial jumps... let's start with an hour
                if abs(minDiff) > 3600 {
                    // is our create diff in this same ballpark? if so, this is probably ok
                    if abs(createDiff) > (0.9 * abs(minDiff)) {
                        // we'll say we're ok
                        self._emitEvent("LARGE JUMP OK? minDiff:\(minDiff) - createDiff:\(createDiff)")
                    } else {
                        self._emitEvent("NON-SENSICAL DATE JUMP? minDiff:\(minDiff) - createDiff:\(createDiff)")
                        // FIXME: what do we do?
                        self.observer.triggerFailure("Non-sensical dates observed.")
                    }
                }
            }

            self._lastDates = dates
        }
    }

    //----------

    deinit {
        self._player.removeObserver(self, forKeyPath: "currentItem")
        self.stop()
    }

    //----------

    private func _computeStreamDates() -> Void {
        let time = self._player.currentItem!.currentTime()

        let curDate = self._player.currentItem!.currentDate()

        var buffered: Double? = nil

        if let loaded_range = self._player.currentItem!.loadedTimeRanges.first?.CMTimeRangeValue {
            buffered = CMTimeGetSeconds(CMTimeSubtract(CMTimeRangeGetEnd(loaded_range), time))
        }

        if curDate != nil {
            // This should be a stream session, with dates

            var minDate: NSDate? = nil
            var maxDate: NSDate? = nil

            if let seek_range = self._player.currentItem!.seekableTimeRanges.first?.CMTimeRangeValue {
                // these calculations assume no discontinuities in the playlist data
                // FIXME: We really want to get these from the playlist... There has to be a way to get there
                minDate = NSDate(timeInterval: -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(seek_range.start)), sinceDate:curDate!)
                maxDate = NSDate(timeInterval: CMTimeGetSeconds(CMTimeRangeGetEnd(seek_range)) - CMTimeGetSeconds(time), sinceDate:curDate!)
            }

            let dates = StreamDates(curDate: curDate!, minDate: minDate, maxDate: maxDate, buffered:buffered)

            self.currentDates = dates

            self.oTime.notify(dates)
        } else {
            // This is likely to be on-demand

            let duration = self.duration()

            let dates = StreamDates(curTime:time, duration:duration)

            self.oTime.notify(dates)
        }

    }

    //----------

    private func _handleObservation(status:AVObserver.Statuses,msg:String,obj:AnyObject?) {
        switch status {
        case .PlayerFailed:
            self._emitEvent("Player failed with error: \(msg)")
        case .ItemFailed:
            self._emitEvent("Item failed with error: \(msg)")
        case .Stalled:
            if self.status != .Playing {
                return;
            }

            if self.currentDates?.hasDates() ?? false {
                self._emitEvent("Playback stalled at \(self._dateFormat.stringFromDate(self.currentDates!.curDate!)).")
            } else {
                self._emitEvent("ONDEMAND AUDIO STALL?")
            }

            // stash our stall position and interaction index, so that we can
            // try to resume in the same spot when we see connectivity return
            let stallIdx = self._interactionIdx
            let stallPosition = self.currentDates?.curDate

            // FIXME: Are the other methods we should be using to try and claw back from a stall?
            self.observer.once(.LikelyToKeepUp) { msg,obj in
                // if there's been a user interaction in the meantime, we do a no-op
                if stallIdx == self._interactionIdx {
                    self._emitEvent("trying to resume playback at stall position.")
                    if stallPosition != nil {
                        self._seekToDate(stallPosition!,useTime:true)
                    } else {
                        self._player.play()
                    }
                }
            }
        case .AccessLog:
            if obj != nil {
                let log = obj as! AVPlayerItemAccessLogEvent
                self._emitEvent("New access log entry: indicated:\(log.indicatedBitrate) -- switch:\(log.switchBitrate) -- stalls: \(log.numberOfStalls) -- durationListened: \(log.durationWatched)")

                self.oAccessLog.notify(log)
            } else {
                self._emitEvent("Access log notification, but no access log found.")
            }
        case .ErrorLog:
            if obj != nil {
                let log = obj as! AVPlayerItemErrorLogEvent
                self._emitEvent("New error log entry \(log.errorStatusCode): \(log.errorComment)")

                self.oErrorLog.notify(log)
            } else {
                self._emitEvent("Error log notification, but no error log found.")
            }
        case .Playing:
            // we're hitting play as part of our seek operations, so don't
            // pass on that status yet if .Seeking
            if self.status != .Seeking {
                self._setStatus(.Playing)
                self._resetLiveDate()
            }
        case .Paused:
            // we pause as part of seeking, so don't pass on that status
            switch (self.status) {
            case .Seeking, .New:
                // do nothing
                true
            default:
                self._setStatus(.Paused)
            }
        case .LikelyToKeepUp:
            self._emitEvent("playback should keep up")
            self._resetLiveDate()

        case .UnlikelyToKeepUp:
            self._emitEvent("playback unlikely to keep up")
        case .TimeJump:
            self._emitEvent("Player reports that time jumped.")

            let lastRecordedTime:String

            if self.currentDates?.hasDates() ?? false {
                lastRecordedTime = self._dateFormat.stringFromDate(self.currentDates!.curDate!)
            } else {
                lastRecordedTime = "Unknown"
            }

            let newDate:String
            if let curDate = self._player.currentItem?.currentDate() {
                newDate = self._dateFormat.stringFromDate(curDate)
            } else {
                newDate = "Unknown"
            }

            self._emitEvent("Time jump! Last recorded time: \(lastRecordedTime). New time: \(newDate)")
        default:
            true
        }
    }

    //----------

    private func _resetLiveDate() {
        self.oTime.once() { dates in
            if let maxDate = dates.maxDate {
                self._emitEvent("Setting liveDate based on maxDate of \(maxDate)")
                self.liveDate = maxDate.dateByAddingTimeInterval(-60)
            }
        }
    }

    //----------

    private func setNetworkStatus() {
        var s:AudioNetworkStatus

        switch self._reachability!.currentReachabilityStatus {
        case .ReachableViaWiFi:
            s = .WIFI
        case .ReachableViaWWAN:
            s = .Cellular
        case .NotReachable:
            s = .NotReachable
        }

        if s != self._networkStatus {
            self._networkStatus = s
            self._emitEvent("Network status is now \(s.toString())")
            self.oNetwork.notify(s)
        }
    }

    //----------

    private func getPlayer() -> AVPlayer {
        return self._player
    }

    //----------

    public func bufferedSecs() -> Double? {
        if let loaded_range = self._player.currentItem?.loadedTimeRanges.first?.CMTimeRangeValue {
            let buffered = CMTimeGetSeconds(CMTimeSubtract(CMTimeRangeGetEnd(loaded_range), self._player.currentTime()))
            return buffered
        } else {
            return nil
        }
    }

    //----------

    private func _emitEvent(msg:String) -> Void {
        let event = AudioEvent(message: msg)
        self.oEventLog.notify(event)
    }

    //----------

    private func _setStatus(s:AudioStatus) -> Void {
        if !(self.status == s) {
            self.prevStatus = self.status
            self.status = s

            self._emitEvent("Player status is now \(s.toString())")
            self.oStatus.notify(s)
        }
    }

    //----------

    public func getAccessLog() -> AVPlayerItemAccessLog? {
        return self._player.currentItem?.accessLog()
    }

    //----------

    public func getErrorLog() -> AVPlayerItemErrorLog? {
        return self._player.currentItem?.errorLog()
    }

    //----------

    public func observeStatus(o:(AudioStatus) -> Void) -> Void {
        self.oStatus.addObserver(o)
    }

    //----------

    public func observeTime(o:(StreamDates) -> Void) -> Void {
        self.oTime.addObserver(o)
    }

    public func observeEvents(o:(AudioEvent) -> Void) -> Void {
        self.oEventLog.addObserver(o)
    }

    //----------

    public func play() -> Bool{
        self._interactionIdx += 1
        self._setStatus(.Waiting)
        self.getPlayer().play()
        return true
    }

    //----------

    public func pause() -> Bool {
        self._interactionIdx += 1
        self._setStatus(.Waiting)
        self.getPlayer().pause()
        return true
    }

    //----------

    public func stop() -> Bool {
        // tear down player and observer
        self.pause()
        self.observer.stop()

        // clean up our time observer
        if self._timeObserver != nil {
            self._player.removeTimeObserver(self._timeObserver!)
        }

        self._timeObserver = nil

        // clear each of our observer types
        // FIXME: I'm a) not sure this is necessary and b) sure there's a better 
        // way to do this
        self.oTime.clear()
        self.oStatus.clear()
        self.oErrorLog.clear()
        self.oAccessLog.clear()
        self.oEventLog.clear()
        self.oNetwork.clear()

        self.currentDates = nil
        self._setStatus(AudioStatus.Stopped)

        return true
    }

    //----------

    public func currentTime() -> CMTime {
        return self._player.currentTime()
    }

    //----------

    public func currentDate() -> NSDate? {
        return self.currentDates?.curDate
    }

    public func duration() -> CMTime {
        return (self._player.currentItem?.asset.duration ?? kCMTimeZero)
    }

    //----------

    private func _getReadyPlayer(c:finishCallback) -> Void {
        if ( self._player.status == AVPlayerStatus.Failed || self._player.currentItem?.status == AVPlayerItemStatus.Failed) {
            self._emitEvent("_getReadyPlayer instead found a failed player/item.");
            return;
        }

        if ( self._player.status == AVPlayerStatus.ReadyToPlay && self._player.currentItem?.status == AVPlayerItemStatus.ReadyToPlay) {
            // ready...
            self._emitEvent("_getReadyPlayer Item was already ready.")
            c(false)
        } else {
            // is the player ready?
            if ( self._player.status == AVPlayerStatus.ReadyToPlay) {
                // yes... so we need to wait for the item
                self._emitEvent("_getReadyPlayer Item not ready. Waiting.")
                self.observer.once(.ItemReady) { msg,obj in
                    self._emitEvent("_getReadyPlayer Item is now ready.")
                    c(true)
                }
            } else {
                // no... wait for the player
                self._emitEvent("_getReadyPlayer Player not ready. Waiting.")
                self.observer.once(.PlayerReady) { msg,obj in
                    self._emitEvent("_getReadyPlayer Player is now ready.")
                    self._getReadyPlayer(c)
                }
            }
        }
    }

    //----------

    public func seekByInterval(interval:NSTimeInterval,completion:finishCallback? = nil) -> Void {
        self._emitEvent("seekByInterval called for \(interval)")

        // get a seek sequence number
        self._interactionIdx += 1
        let seek_id = self._interactionIdx

        self._getReadyPlayer() { cold in
            if (self._interactionIdx != seek_id) {
                self._emitEvent("seekByInterval interrupted.")
                completion?(false)
                return;
            }

            self._setStatus(.Seeking)

            // we need to start playing before any seek operations
            // FIXME: Add volume management?
            if self._player.rate != 1.0 {
                self._emitEvent("seekByInterval Hitting play before seeking")
                self._player.play()
            }

            let seek_time = CMTimeAdd(self._player.currentItem!.currentTime(), CMTimeMakeWithSeconds(interval, 1000))
            self._player.currentItem!.seekToTime(seek_time, toleranceBefore:kCMTimeZero, toleranceAfter:kCMTimeZero) {finished in
                self._computeStreamDates()
                self._setStatus(.Playing)
                self._player.play()
                completion?(finished)
            }

        }
    }

    //----------

    public func seekToDate(date:NSDate, completion:Block? = nil) -> Void {
        self._seekToDate(date, completion:completion);
    }

    public func _seekToDate(date: NSDate,retries:Int = 2,useTime:Bool = false,completion:Block? = nil) -> Void {
        let fsig = "seekToDate (" + ( useTime ? "time" : "date" ) + ") "

        // do we think we can do this?
        // FIXME: check currentDates if we have them
        self._emitEvent(fsig + "called for \(self._dateFormat.stringFromDate(date))")

        // get a seek sequence number
        self._interactionIdx += 1
        let seek_id = self._interactionIdx

        self._getReadyPlayer() { cold in
            guard let _ = self._player.currentItem else {
                self._emitEvent(fsig+"seek aborted (currentItem is nil).")
                completion?()
                return
            }

            guard let _ = self._player.currentItem!.currentDate() else {
                self._emitEvent(fsig+"seek aborted (currentDate is nil).")
                completion?()
                return
            }

            if (self._interactionIdx != seek_id) {
                self._emitEvent(fsig+"seek interrupted.")
                completion?()
                return;
            }

            self._setStatus(.Seeking)

            // we need to start playing before any seek operations
            // FIXME: Add volume management?
            if self._player.rate != 1.0 {
                self._emitEvent(fsig+"Hitting play before seeking")
                self._player.play()
            }

            let playFunc = { (finished:Bool) -> Void in
                // we're already "playing". Just change our status
                // FIXME: Add volume management?
                self._computeStreamDates()
                self._setStatus(.Playing)
                self._player.play()
                completion?()
            }

            // Set up common code for testing our landing position
            let testLanding = { (finished:Bool) -> Void in

                if finished {
                    guard let _ = self._player.currentItem else {
                        self._emitEvent(fsig+"seek aborted at landing (currentItem is nil).")
                        playFunc(false)
                        return
                    }

                    // how close did we get?
                    guard let landed = self._player.currentItem!.currentDate() else {
                        self._emitEvent(fsig+"seek aborted at landing (currentDate is nil).")
                        playFunc(false)
                        return
                    }

                    self._emitEvent(fsig+"landed at \(self._dateFormat.stringFromDate(landed))")

                    if abs( Int(date.timeIntervalSinceReferenceDate - landed.timeIntervalSinceReferenceDate) ) <= self.seekTolerance {
                        // success! start playing
                        self._emitEvent(fsig+"hitting play")
                        playFunc(true)

                    } else {
                        // not quite... try again, as long as we have retries
                        if self._interactionIdx == seek_id {
                            switch retries {
                            case 0:
                                self._emitEvent("seekToDate ran out of retries. Playing from here.")
                                playFunc(true)
                            case 1:
                                // last try always uses time
                                self._seekToDate(date, retries: retries-1, useTime:true, completion:completion)
                            default:
                                self._seekToDate(date, retries: retries-1, completion:completion)
                            }
                        }
                    }
                } else {
                    self._emitEvent(fsig+"did not finish.")

                    // if we get here, but our seek_id is still the current one, we should retry. If
                    // id has changed, there's another seek operation started and we should stop
                    if self._interactionIdx == seek_id {
                        switch retries {
                        case 0:
                            self._emitEvent("seekToDate is out of retries")
                            playFunc(false)

                        case 1:
                            self._seekToDate(date, retries: retries-1, useTime:true, completion:completion)
                        default:
                            self._seekToDate(date, retries: retries-1, completion:completion)
                        }
                    } else {
                        playFunc(false)
                    }
                }
            }

            // SEEK!

            // how far are we trying to go?
            // FIXME: if we don't have a current date, is it more appropriate to 
            // error rather than trying seekToDate?
            let cdint = self._player.currentItem!.currentDate()?.timeIntervalSinceReferenceDate
            let offsetSeconds:Double? = cdint != nil ? (date.timeIntervalSinceReferenceDate - cdint!) : nil

            // we'll cheat and use time for short seeks, which seem to
            // sometimes leave seekToDate stuck playing a loop
            // also, a cold seek with seekToDate never works, so start with seekToTime

            if (offsetSeconds != nil && cold || useTime || abs(offsetSeconds!) < 60) {
                let seek_time = CMTimeAdd(self._player.currentItem!.currentTime(), CMTimeMakeWithSeconds(offsetSeconds!, 1000))
                self._emitEvent(fsig+"seeking \(offsetSeconds) seconds.")
                self._player.currentItem!.seekToTime(seek_time, toleranceBefore:kCMTimeZero, toleranceAfter:kCMTimeZero, completionHandler:testLanding)
            } else {
                // use seekToDate
                self._player.currentItem!.seekToDate(date, completionHandler:testLanding)
            }
        }
    }

    //----------

    public func seekToPercent(percent: Float64,completion:Block? = nil) -> Bool {
        let str_per = String(format:"%2f", percent)
        self._emitEvent("seekToPercent called for \(str_per)")

        if (self._player.currentItem?.duration > kCMTimeZero) {
            // this is an on-demand file, so just seek using the percentage
            let dur = self._player.currentItem!.duration
            let seek_time = CMTimeMultiplyByFloat64(dur, percent)

            self._seekToTime(seek_time,completion:completion)
            return true

        } else {
            // convert percent into a date and then just call seekToDate
            if self.currentDates != nil {
                let date = self.currentDates!.percentToDate(percent)

                if date != nil {
                    self.seekToDate(date!,completion:completion)
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }

        }
    }

    //----------

    private func _seekToTime(time:CMTime,completion:Block?) -> Void {
        self._emitEvent("_seekToTime called for \(time)")

        self._interactionIdx += 1
        let seek_id = self._interactionIdx

        self._getReadyPlayer() { cold in
            if (self._interactionIdx != seek_id) {
                self._emitEvent("_seekToTime: seek interrupted.")
                completion?()
                return;
            }

            self._setStatus(.Seeking)

            if self._player.rate != 1.0 {
                self._player.play()
            }

            guard let currentItem = self._player.currentItem else {
                completion?()
                return
            }

            var time = time

            if CMTIME_IS_INDEFINITE(time) {
                time = kCMTimePositiveInfinity
            }

            currentItem.seekToTime(time) { finished in
                self._computeStreamDates()
                self._setStatus(.Playing)
                self._player.play()
                completion?()
            }
        }
    }

    //----------

    public func seekToLive(completion:Block?) -> Void {
        self._emitEvent("seekToLive called")
        self._seekToTime(kCMTimePositiveInfinity) { finished in

            // we've asked to seek to live and landed here, so let's count this 
            // as our live date.
            if let curDate = self._player.currentItem?.currentDate() {
                self._emitEvent("seekToLive landed at \(self._dateFormat.stringFromDate(curDate))")
                self.liveDate = curDate
            }

            completion?()
        }
    }

    //----------

    // Workaround added for KVO crash [Fabric #49]
    // REASON: AVObserver does not handle case that AVPlayerItem (aka currentItem) is deallocated before the AVPlayer
    // TODO: Fix KVO logic in AVObserver
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let keyPath = keyPath else { return }
        if object as? AVPlayer == self._player && keyPath == "currentItem" {
            if let _playerItem = _playerItem where self._player.currentItem == nil && !observer.isDestroyed {
                _playerItem.removeObserver(observer, forKeyPath: "status")
                _playerItem.removeObserver(observer, forKeyPath: "playbackLikelyToKeepUp")
            }
            _playerItem = self._player.currentItem
        }
    }
}
