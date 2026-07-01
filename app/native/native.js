/* =========================================================================
   Ya Spa — native layer (Capacitor only). No-ops on the plain website.
   Injected into the app build automatically by scripts/copy-web.mjs.

   Adds the "this is a real app, not a wrapped site" behaviour that also helps
   clear App Store guideline 4.2:
     • themed native status bar + hides the web "install" hint
     • push-notification registration (booking / therapist-on-the-way / offers)
     • native share
   All plugins are optional — each is guarded so a missing plugin never throws.
   ========================================================================= */
(function () {
  'use strict';
  var Cap = window.Capacitor;
  if (!Cap || !Cap.isNativePlatform || !Cap.isNativePlatform()) return;   // website → do nothing
  var P = Cap.Plugins || {};

  // ---- Status bar theming ------------------------------------------------
  try {
    if (P.StatusBar) { P.StatusBar.setStyle({ style: 'LIGHT' }); P.StatusBar.setBackgroundColor({ color: '#9E2B52' }); }
  } catch (e) {}

  // ---- Hide the web-only "Install app" button (we ARE the app) -----------
  document.addEventListener('DOMContentLoaded', function () {
    var b = document.getElementById('installBtn'); if (b) b.hidden = true;
  });

  // ---- Push notifications (APNs) -----------------------------------------
  // Requires: @capacitor/push-notifications + your APNs auth key (.p8) configured
  // in your push backend. In Xcode, enable the "Push Notifications" capability.
  try {
    var Push = P.PushNotifications;
    if (Push) {
      Push.requestPermissions().then(function (r) {
        if (r && r.receive === 'granted') Push.register();
      });
      Push.addListener('registration', function (t) {
        // TODO: send t.value (device token) to your backend to target this user.
        console.log('push token', t && t.value);
      });
      Push.addListener('pushNotificationActionPerformed', function (a) {
        // Deep-link into the relevant screen when a notification is tapped.
        var url = a && a.notification && a.notification.data && a.notification.data.url;
        if (url) location.hash = url;
      });
    }
  } catch (e) {}

  // ---- Native share helper (call window.YaSpaShare() from a button) ------
  window.YaSpaShare = function (text) {
    try {
      if (P.Share) return P.Share.share({
        title: 'Ya Spa', text: text || 'احجزي مساج نسائي بالبيت مع يا سبا 🌸', url: 'https://yaspa.sa'
      });
    } catch (e) {}
  };
})();
