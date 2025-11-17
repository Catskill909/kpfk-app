# Lock Screen Image Display Mechanism Audit

## Executive Summary

This document maps the complete metadata image flow from API to lockscreen display in the WPFW Radio app, identifying potential causes for intermittent image display failures.

## Image Data Flow Architecture

### 1. Single Source of Truth: API Response
**Location**: `https://confessor.wpfwfm.org/playlist/_pl_current_ary.php`
**Field**: `sh_photo` in the current show object
**Processing**: Raw URL string from API → `ShowInfo.hostImage` property

### 2. Data Flow Chain

```
API Response → MetadataService → StreamRepository → UI Components + iOS Native
     ↓              ↓               ↓                    ↓
sh_photo → ShowInfo.hostImage → MediaItem.artUri → Image.network + MPMediaItemArtwork
```

## Critical Components Analysis

### A. MetadataService (Dart)
**File**: `/lib/services/metadata_service.dart`
- **Responsibility**: Fetches raw API data every 15 seconds
- **Image Handling**: Passes `sh_photo` field directly to `ShowInfo.hostImage`
- **No Image Processing**: Raw URL string passed through unchanged
- **Potential Issues**: 
  - Network timeouts (5s timeout)
  - API response format changes
  - Empty/null `sh_photo` values

### B. ShowInfo Model (Dart)
**File**: `/lib/domain/models/stream_metadata.dart`
- **Image Property**: `String? hostImage`
- **Validation**: `hasHostImage` getter checks for null/empty
- **Processing**: No URL validation or sanitization
- **Potential Issues**:
  - Invalid URL formats not caught
  - No fallback image mechanism

### C. StreamRepository (Dart)
**File**: `/lib/data/repositories/stream_repository.dart`
- **Method**: `_updateMediaMetadata()`
- **Image Flow**: `showInfo.hostImage` → `MediaItem.artUri` → Native iOS
- **Dual Path**: 
  1. Flutter `MediaItem` for Android/basic iOS
  2. Native iOS `NativeMetadataService` for lockscreen
- **Potential Issues**:
  - Race conditions between dual updates
  - No image caching at Dart level

### D. HomePage UI (Dart)
**File**: `/lib/presentation/pages/home_page.dart`
- **Display Method**: `Image.network()` widget
- **Error Handling**: `errorBuilder` shows "Error loading image"
- **Caching**: Relies on Flutter's default network image caching
- **Potential Issues**:
  - Network image cache eviction
  - No retry mechanism for failed loads

### E. NativeMetadataService (Dart)
**File**: `/lib/services/metadata_service_native.dart`
- **Method**: `updateLockscreenMetadata()`
- **Image Handling**: Passes `artworkUrl` to iOS native code
- **Throttling**: 5-second throttle with significant change detection
- **Potential Issues**:
  - Throttling may skip image updates
  - No image validation before sending to native

### F. iOS Native Implementation (Swift)
**File**: `/ios/Runner/AppDelegate.swift`
- **Method**: `handleUpdateMetadata()` and `applyPendingMetadataUpdate()`
- **Image Processing**: 
  1. Preserves existing artwork to prevent clearing
  2. Downloads new images via `URLSession`
  3. Creates `MPMediaItemArtwork` objects
  4. Updates `MPNowPlayingInfoCenter`
- **Caching**: 
  - `cachedArtwork` property caches last successful download
  - `lastArtworkUrl` tracks URL changes
- **Debouncing**: 250ms timer prevents excessive updates

## Identified Potential Issues

### 1. Race Conditions
**Scenario**: Multiple metadata updates in rapid succession
**Impact**: Image downloads may be cancelled or overwritten
**Location**: iOS `URLSession.shared.dataTask` in `applyPendingMetadataUpdate()`

### 2. Network Image Failures
**Scenario**: API returns valid metadata but image URL is unreachable
**Impact**: Lockscreen shows metadata without image, app shows error
**Gaps**: 
- No retry mechanism for failed image downloads
- No fallback image system
- No image URL validation

### 3. Cache Inconsistencies
**Scenario**: Flutter cache and iOS cache become desynchronized
**Impact**: App shows image but lockscreen doesn't (or vice versa)
**Locations**:
- Flutter `Image.network` cache vs iOS `cachedArtwork`
- No shared cache invalidation strategy

### 4. Throttling Side Effects
**Scenario**: Rapid metadata changes with same image URL
**Impact**: Image updates may be throttled even when needed
**Location**: `NativeMetadataService._isSignificantMetadataChange()`

### 5. Memory Pressure
**Scenario**: iOS system under memory pressure
**Impact**: Cached artwork may be deallocated
**Location**: iOS `cachedArtwork` property not using weak references

### 6. Background App State
**Scenario**: App backgrounded during image download
**Impact**: Download may be suspended or cancelled
**Location**: iOS `URLSession` tasks in background

## Image Display Paths

### App Bar Controls Image
1. **Source**: `state.metadata?.current.hostImage`
2. **Widget**: `Image.network()` in `home_page.dart`
3. **Caching**: Flutter's default `NetworkImage` cache
4. **Error Handling**: Shows "Error loading image" container

### Lockscreen Image
1. **Source**: Same `hostImage` from metadata
2. **Path**: Dart → iOS MethodChannel → Swift URLSession → MPMediaItemArtwork
3. **Caching**: iOS `cachedArtwork` property + system cache
4. **Error Handling**: Silent failure, preserves existing artwork

## Recommendations for Investigation

### 1. Add Comprehensive Logging
- Log image URL at each stage of the flow
- Track image download success/failure rates
- Monitor cache hit/miss ratios

### 2. Implement Image Validation
- Validate URLs before attempting downloads
- Add HEAD request checks for image accessibility
- Implement fallback image mechanism

### 3. Synchronize Caching
- Implement shared cache invalidation
- Add cache warming strategies
- Monitor memory usage of cached images

### 4. Add Retry Mechanisms
- Retry failed image downloads with exponential backoff
- Implement circuit breaker pattern for consistently failing URLs
- Add manual refresh capability

### 5. Monitor Network Conditions
- Track network quality during image downloads
- Implement adaptive timeout strategies
- Add offline image caching

## Conclusion

The intermittent image display issue likely stems from network-related failures in the iOS native image download process, combined with potential race conditions and cache inconsistencies. The dual-path architecture (Flutter + iOS native) creates multiple points of failure without synchronized error handling.

The most probable culprits are:
1. **Network timeouts** during iOS `URLSession` downloads
2. **Race conditions** when multiple metadata updates occur rapidly  
3. **Cache desynchronization** between Flutter and iOS layers
4. **Memory pressure** causing iOS artwork cache eviction

A comprehensive logging strategy should be implemented first to identify the specific failure patterns before implementing targeted fixes.
