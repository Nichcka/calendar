'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"manifest.json": "b45a5ae312dcbae34307baec3eefbfe1",
"main.dart.js": "c1718677026a79197c39e8f086ab6f39",
"icons/Icon-512.png": "fa8de72fc091ad2cbbe567eb22b1fc69",
"icons/Icon-maskable-192.png": "b5a4b71ba6be5a27609fca5623d49f72",
"icons/Icon-maskable-512.png": "fa8de72fc091ad2cbbe567eb22b1fc69",
"icons/Icon-192.png": "b5a4b71ba6be5a27609fca5623d49f72",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"favicon.png": "77c15b486df9a6d3b5eff1921f347c39",
"index.html": "1137687bd22a40af9c5cf9328059ffa9",
"/": "1137687bd22a40af9c5cf9328059ffa9",
"flutter_bootstrap.js": "0536c63480d386d9a4a0b02c0022af0e",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"version.json": "e7e5c06e77b268f229ec24fce4e015b3",
"assets/AssetManifest.bin": "e90d90692a3136022a95feff49a1febf",
"assets/FontManifest.json": "68d947a8bdb578f0e59695ffdccae784",
"assets/NOTICES": "26fac9078a763448f53694d3f857eb06",
"assets/AssetManifest.json": "11b05b67a6a210089a25c4589b9d1c48",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/fonts/MaterialIcons-Regular.otf": "d1be414a8de21464c6239cd145309dc3",
"assets/AssetManifest.bin.json": "5c35ce3130b68a472d08ddbbcabd3f78",
"assets/assets/images/icon.PNG": "75dbfcdc9a046029df5617055ee487c7",
"assets/assets/fonts/Cygre-Regular.ttf": "63a32705a2b2a2238855b1bd1f9dd18f",
"assets/assets/fonts/Cygre-BlackIt.ttf": "b7e43b9b9a53a0ba77cad0421b7a1223",
"assets/assets/fonts/Cygre-Light.ttf": "2e46652a2dcb3173f0d40d4266f1debe",
"assets/assets/fonts/Cygre-Black.ttf": "eacf49ba35fbd05c8330db2ae2b2e046",
"assets/assets/fonts/Cygre-SemiBoldIt.ttf": "6ac924ba70cb060722071dcf1639ad4a",
"assets/assets/fonts/Cygre-LightIt.ttf": "9d87287f8d0f4500a15555372996c2aa",
"assets/assets/fonts/Cygre-Medium.ttf": "a4d874c0fdb8ec852ef998a615b24b6f",
"assets/assets/fonts/Cygre-ThinIt.ttf": "c7a535a15cfa8b245c8f3e6242a4bd2e",
"assets/assets/fonts/Cygre-SemiBold.ttf": "0d9ceffc71bf56206391dcfb74714fbf",
"assets/assets/fonts/Cygre-Thin.ttf": "33a9750b3a7414443561ac9da24f9d23",
"assets/assets/fonts/Cygre-Bold.ttf": "f872553ca84d7072b34c742902d20776",
"assets/assets/fonts/Cygre-MediumIt.ttf": "5dc1c3d1fa25d3c144cafaa1c304497f",
"assets/assets/fonts/Cygre-BoldIt.ttf": "3f6df3ccd4a583ee6a39c32075fa311c",
"assets/assets/fonts/Cygre-RegularIt.ttf": "5727ffc1384b8b8bda80848f0892e479"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
