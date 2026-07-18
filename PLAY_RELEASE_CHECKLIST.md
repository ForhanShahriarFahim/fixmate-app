# Google Play internal testing checklist

- [ ] Replace Firebase placeholders and confirm `com.fixmatebd.app` in Firebase and Play Console.
- [ ] Generate and commit `pubspec.lock`; run Flutter analyzer and all tests.
- [ ] Keep Firebase on Spark; deploy Firestore Rules/indexes and seed categories.
- [ ] Verify provider approval, conflict prevention, contact release, chat/block/report, completion, review, and deletion with two real test accounts.
- [ ] Enable Crashlytics and verify one non-fatal test event.
- [ ] Validate App Check monitoring, then enforce before beta promotion.
- [ ] Reserve `fixmatebd.support@gmail.com` and verify support mailto links.
- [ ] Publish GitHub Pages and replace the owner in legal URLs if necessary.
- [ ] Review Terms and Privacy Policy with the publisher/legal adviser.
- [ ] Complete Play Data safety, account deletion URL, UGC/content-rating, and privacy policy declarations accurately.
- [ ] Create a non-debug upload keystore and provide secure `android/key.properties` values for the release build.
- [ ] Re-run `npm audit --omit=dev` and review whether the upstream Firebase Admin `uuid` advisory has a non-breaking fix.
- [ ] Build an AAB, install via internal testing, and test in-app booking/message activity on a physical Android device.
- [ ] Confirm no billing account is linked and monitor Firestore Spark quotas.
