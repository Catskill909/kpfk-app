# Lockscreen Pause Button Image Clearing Bug - Deep Analysis

## Critical Bug Description

When the lockscreen pause button is pressed, the audio correctly resets to initial state, but the metadata image is permanently cleared from both lockscreen and app bar controls and never recovers, even when new metadata arrives.

## Root Cause Analysis

### The Destructive Chain Reaction

1. **Lockscreen Pause Button Pressed** → iOS `remotePause` command
2. **NativeMetadataService** routes to `StreamRepository.pause()`
3. **StreamRepository.pause()** calls `stopAndColdReset()`
4. **stopAndColdReset()** explicitly calls `iosLock.clearLockscreen()`
5. **clearLockscreen()** sets `MPNowPlayingInfoCenter.default().nowPlayingInfo = nil`
6. **Metadata Never Recovers** because the system is designed to preserve existing artwork

## Conflicting Design Philosophies

### Audio Reset Logic (Working Correctly)
- **Purpose**: Prevent stuck audio states
- **Method**: Complete pipeline reset via `stopAndColdReset()`
- **Result**: Clean audio state ✅

### Metadata Preservation Logic (Conflicting)
- **Purpose**: Prevent image flickering during updates
- **Method**: Preserve existing artwork in iOS native code
- **Result**: Once cleared, images never return ❌

## Code Flow Analysis

### 1. Lockscreen Pause Command Flow
```
iOS Lockscreen Pause Button
    ↓
AppDelegate.swift remotePause handler
    ↓
NativeMetadataService.remotePause (line 50-63)
    ↓
StreamRepository.pause() (line 216-230)
    ↓
stopAndColdReset() (line 53-80)
    ↓
iosLock.clearLockscreen() (line 63)
    ↓
MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
```

### 2. Metadata Recovery Attempt Flow
```
MetadataService continues fetching every 15s
    ↓
StreamRepository._updateMediaMetadata() (line 294-368)
    ↓
NativeMetadataService.updateLockscreenMetadata() (line 171-268)
    ↓
AppDelegate.handleUpdateMetadata() (line 264+)
    ↓
applyPendingMetadataUpdate() preserves existing artwork (line 135-151)
    ↓
NO NEW ARTWORK because existing artwork is nil and URL hasn't changed
```

## The Preservation Trap

### iOS Native Code Issue (AppDelegate.swift lines 135-151)
```swift
// CRITICAL FIX: Always preserve existing artwork to prevent override clearing
let existingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
let existingArtwork = existingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork

// Use cached artwork if same URL, or preserve existing artwork
if let currentUrl = currentArtworkUrl, currentUrl == self.lastArtworkUrl, let cachedArtwork = self.cachedArtwork {
    // Same artwork URL - use cached artwork immediately
    nowPlayingInfo[MPMediaItemPropertyArtwork] = cachedArtwork
} else if let existingArtwork = existingArtwork {
    // Preserve existing artwork to prevent clearing
    nowPlayingInfo[MPMediaItemPropertyArtwork] = existingArtwork
}
```

**The Problem**: After `clearLockscreen()` sets `nowPlayingInfo = nil`, there is no existing artwork to preserve, and the cached artwork is also cleared. The system then never downloads new artwork because the URL hasn't changed.

## State Management Conflicts

### Multiple Sources of Truth
1. **iOS `cachedArtwork`** - Cleared during reset
2. **iOS `lastArtworkUrl`** - Tracks URL changes for download decisions
3. **iOS `MPNowPlayingInfoCenter`** - System lockscreen display
4. **Dart `_currentMetadata`** - App-level metadata state
5. **MetadataService cache** - API response caching

### The Recovery Failure
After pause/reset:
- `cachedArtwork` = nil
- `lastArtworkUrl` = still contains previous URL
- New metadata arrives with same `hostImage` URL
- System thinks "same URL, use cached artwork"
- But cached artwork is nil → no image displayed
- No new download triggered because URL "hasn't changed"

## Critical Design Flaw

### The Pause Operation Does Too Much
`StreamRepository.pause()` is designed to:
1. ✅ Stop audio playback
2. ✅ Reset audio pipeline
3. ❌ Clear ALL metadata (including images)
4. ❌ Clear cached artwork references

### What Should Happen
`StreamRepository.pause()` should:
1. ✅ Stop audio playback
2. ✅ Reset audio pipeline  
3. ✅ Update playback state to paused
4. ❌ **PRESERVE** metadata and images

## Solution Strategy

### Option 1: Selective Reset (RECOMMENDED)
Modify `stopAndColdReset()` to preserve metadata while resetting audio:
- Stop audio playback
- Reset audio pipeline
- **SKIP** `clearLockscreen()` call
- **PRESERVE** `_currentMetadata`
- Update lockscreen with paused state but keep image

### Option 2: Force Metadata Refresh
After audio reset, force a complete metadata refresh:
- Clear iOS artwork cache (`cachedArtwork = nil`, `lastArtworkUrl = nil`)
- Force immediate metadata re-download
- Update lockscreen with fresh metadata

### Option 3: Separate Pause vs Stop
Create distinct operations:
- **Pause**: Stop audio, preserve metadata
- **Stop**: Full reset including metadata clearing
- Use pause for lockscreen button, stop for app termination

## Recommended Implementation

### Phase 1: Preserve Metadata During Pause
1. Modify `stopAndColdReset()` to accept a `preserveMetadata` parameter
2. Skip `clearLockscreen()` when preserving metadata
3. Keep `_currentMetadata` intact
4. Update lockscreen with paused state

### Phase 2: Fix iOS Artwork Cache Logic
1. Modify iOS native code to force re-download when cache is cleared
2. Add cache invalidation when `clearLockscreen()` is called
3. Ensure artwork downloads even with same URL after reset

### Phase 3: Unified State Management
1. Create single source of truth for metadata state
2. Synchronize all caches when state changes
3. Add recovery mechanisms for desynchronized states

## Testing Strategy

### Reproduce Bug
1. Start audio playback with metadata image
2. Press lockscreen pause button
3. Verify image disappears and doesn't return
4. Check logs for artwork preservation logic

### Verify Fix
1. Implement metadata preservation
2. Test pause button preserves image
3. Test audio still resets correctly
4. Test recovery from various states

## Conclusion

The bug is caused by overly aggressive metadata clearing during audio reset, combined with iOS artwork preservation logic that prevents recovery. The solution requires separating audio reset from metadata clearing, allowing the pause operation to maintain visual continuity while achieving the desired audio state reset.
