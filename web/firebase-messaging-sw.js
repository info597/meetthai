importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAHctXyl8UR8uW1XDiZ560DyMoz04WBSFs",
  authDomain: "meet-thai-dating.firebaseapp.com",
  projectId: "meet-thai-dating",
  storageBucket: "meet-thai-dating.firebasestorage.app",
  messagingSenderId: "541550784769",
  appId: "1:541550784769:web:53f4ba50c4cdecaae72b00"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const notificationTitle =
    (payload && payload.notification && payload.notification.title) || 'Meet Thai';

  const notificationOptions = {
    body:
      (payload && payload.notification && payload.notification.body) ||
      'Neue Nachricht',
    data: (payload && payload.data) || {}
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if ('focus' in client) {
          return client.focus();
        }
      }

      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});