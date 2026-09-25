importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: 'AIzaSyBcB0-ayrnEtRKl3rzK0nI_MqGSOK0fXWg',
  authDomain: 'assisthub-59ed4.firebaseapp.com',
  projectId: 'assisthub-59ed4',
  storageBucket: 'assisthub-59ed4.firebasestorage.app',
  messagingSenderId: '726383292908',
  appId: '1:726383292908:web:bae6ecfe24e6814b5b50c9',
});

const messaging = firebase.messaging();