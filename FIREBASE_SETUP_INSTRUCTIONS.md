# Firebase SDK Setup Instructions

## 1. Add Firebase SDKs to Xcode Project

### In Xcode:
1. **File → Add Package Dependencies**
2. **Add Firebase URL**: `https://github.com/firebase/firebase-ios-sdk`
3. **Select these packages**:
   - `FirebaseCrashlytics`
   - `FirebasePerformance` 
   - `FirebaseFirestore` (already added)
   - `FirebaseAuth` (already added)
   - `FirebaseStorage` (already added)

## 2. Configure Crashlytics dSYM Upload

### Add Build Phase Script:
1. **Xcode → Target → Build Phases → + → New Run Script Phase**
2. **Name**: "Upload dSYMs to Crashlytics"
3. **Shell**: `/bin/sh`
4. **Script**:
```bash
# Only run for device builds and release builds
if [[ "$PLATFORM_NAME" == "iphoneos" ]] || [[ "$CONFIGURATION" == "Release" ]]; then
    "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
else
    echo "Skipping Crashlytics upload for simulator/debug build"
fi
```

### Input Files:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}
${BUILT_PRODUCTS_DIR}/GoogleService-Info.plist
```

## 3. Update Build Settings

### Debug Information Format:
- **Debug**: `DWARF with dSYM File`
- **Release**: `DWARF with dSYM File`

### Other Settings:
- **Generate Debug Symbols**: `YES`
- **Strip Debug Symbols During Copy**: `NO` (for Debug), `YES` (for Release)

## 4. Firebase Console Setup

### Enable Crashlytics:
1. Go to Firebase Console → Your Project
2. **Crashlytics** → Get Started
3. Follow setup instructions
4. **Performance** → Get Started
5. Enable Performance Monitoring

### Set up Alerts:
1. **Crashlytics** → Alerts
2. **New Alert** → Crash-free users drops below 99%
3. **New Alert** → New issue detected
4. **Performance** → Alerts
5. **New Alert** → App start time > 2 seconds

## 5. Deploy Firebase Rules

The monitoring collections are already configured in `firestore.rules`:
- `debug_logs` - Remote logging data
- `error_reports` - Error reports with context
- `bug_reports` - User bug reports

Deploy with:
```bash
firebase deploy --only firestore:rules
```

## 6. Test the Setup

### Test Crash Reporting:
1. **Debug Menu** → Live Monitoring → "Trigger Test Crash" (DEBUG builds only)
2. Check Firebase Console → Crashlytics for the crash report

### Test Performance:
1. Launch the app and navigate around
2. Check Firebase Console → Performance for metrics

### Test Remote Logging:
1. **Debug Menu** → Live Monitoring → "Send Test Log"
2. Check Firebase Console → Firestore → `debug_logs` collection

## 7. Production Checklist

- [ ] Firebase SDKs added to Xcode
- [ ] dSYM upload script configured
- [ ] Build settings updated
- [ ] Crashlytics enabled in Firebase Console
- [ ] Performance Monitoring enabled
- [ ] Firebase rules deployed
- [ ] Alerts configured
- [ ] Test crash/performance/logging working

## 8. Monitoring Dashboard Access

**Admin users** can access the Live Monitoring dashboard:
1. **Profile** → **Live Monitoring** (admin only)
2. Real-time logs, errors, and performance metrics
3. Debug actions for testing

## 9. TestFlight Best Practices

### Before TestFlight Release:
1. Test all monitoring features in development
2. Verify crash reports appear in Firebase Console
3. Check performance metrics are being collected
4. Test the Live Monitoring dashboard

### During TestFlight:
1. Monitor Firebase Console daily for crashes/performance issues
2. Use Live Monitoring dashboard to watch real-time issues
3. Respond to user feedback with debug information requests
4. Track key metrics: crash-free rate, app start time, AI analysis performance

### Key Metrics to Watch:
- **Crash-free sessions**: > 99.5%
- **App launch time**: < 2 seconds (p95)
- **AI analysis time**: < 10 seconds (p95)
- **Memory usage**: < 200MB typical
- **Network error rate**: < 2%

This setup provides production-grade monitoring that scales from TestFlight to App Store release.
