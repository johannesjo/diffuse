let node = document.getElementById("elm-container");
let userProps = ["displayName", "email", "photoURL", "refreshToken", "uid"];
let didSetupElm = false;



//
// Firebase

const firebaseConfig = {
  apiKey: "AIzaSyCEblV1BTVwpMCdAWZlchV23qJCsW_PCjw",
  authDomain: "ongaku-ryoho-v3-test.firebaseapp.com",
  databaseURL: "https://ongaku-ryoho-v3-test.firebaseio.com"
};

firebase.initializeApp(firebaseConfig);
firebase.auth().getRedirectResult(); // TODO - Handle errors
firebase.auth().onAuthStateChanged(authStatechange); // TODO - Handle errors


function authStatechange(userObj) {
  if (didSetupElm) return;

  // check user props
  const maybeUser = userObj ? _.pick(userProps, userObj) : null;

  // {unauthenticated}
  if (!maybeUser) {
    setupElm({ user: maybeUser });
    return;
  }

  // {authenticated}
  Promise.all([
    firebase.database().ref(`/users/${maybeUser.uid}/sources`).once("value"),
    firebase.database().ref(`/users/${maybeUser.uid}/tracks`).once("value")
  ]).then(
    x => x.map(s => s.val())
  ).then(
    x => setupElm({ user: maybeUser, sources: x[0], tracks: x[1] })
  ).catch(
    e => {
      // TODO: Show error message
      console.error("Could not load data");
      console.error(e);
    }
  );
}


function storeData(key, data) {
  const obj = {};
  const userId = firebase.auth().currentUser.uid;

  obj[key] = data;
  firebase.database().ref(`/users/${userId}`).update(obj);
}



//
// Settings

function saveSettings(key, settings) {
  localStorage.setItem("settings." + key, JSON.stringify(settings));
}


function loadSettings(key) {
  let val = localStorage.getItem("settings." + key);
  if (!val || !val.length) return null;

  try {
    return JSON.parse(val);
  } catch (_) {
    return null;
  }
}



//
// Elm

function setupElm(params) {
  didSetupElm = true;

  // Clean
  node.innerHTML = "";

  // Embed
  const app = Elm.App.embed(
    node,
    { settings:
        { queue: loadSettings("queue") || { repeat: false, shuffle: false }
        }
    , sources: params.sources
    , tracks: params.tracks
    , user: params.user
    }
  );

  // Ports
  // > Authentication
  app.ports.authenticate.subscribe(() => {
    firebase.auth().signInWithRedirect(
      new firebase.auth.GoogleAuthProvider()
    );
  });

  // > Audio
  var audioEnvironmentContext = {
    activeQueueItem: null,
    elm: app
  };

  app.ports.activeQueueItemChanged.subscribe(item => {
    const timestampInMilliseconds = Date.now();

    audioEnvironmentContext.activeQueueItem = item;
    audioEnvironmentContext.audio = null;

    if (item) {
      createAudioElement(audioEnvironmentContext, item);
      removeOlderAudioElements(timestampInMilliseconds);
    } else {
      removeOlderAudioElements(timestampInMilliseconds);
      app.ports.setIsPlaying.send(false);
      app.ports.setProgress.send(0);
    }
  });

  app.ports.requestPlay.subscribe(_ => {
    if (audioEnvironmentContext.audio) {
      audioEnvironmentContext.audio.play();
    }
  });

  app.ports.requestPause.subscribe(_ => {
    if (audioEnvironmentContext.audio) {
      audioEnvironmentContext.audio.pause();
    }
  });

  app.ports.requestSeek.subscribe(percentage => {
    const audio = audioEnvironmentContext.audio;

    if (audio && !isNaN(audio.duration)) {
      audio.currentTime = audio.duration * percentage;
    }
  });

  // > Processing
  app.ports.requestTags.subscribe(distantContext => {
    const context = Object.assign({}, distantContext);
    const initialPromise = Promise.resolve([]);

    return context.urlsForTags.reduce((accumulator, urls) => {
      return accumulator.then(
        col => {
          return getTags(urls.getUrl, urls.headUrl)
            .then(r => col.concat(r))
            .catch(_ => col.concat(null));
        }
      );

    }, initialPromise).then(col => {
      context.receivedTags = col.map(pickTags);
      app.ports.receiveTags.send(context);

    });
  });

  // > Data
  app.ports.storeSources.subscribe(v => storeData("sources", v));
  app.ports.storeTracks.subscribe(v => storeData("tracks", v));

  app.ports.storeQueueSettings.subscribe(settings => {
    saveSettings("queue", settings);
  });
}
