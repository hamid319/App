// TripFam web invite: friends open /join/<CODE> from WhatsApp, join the trip
// without installing the app, and like ideas or vote in polls.
//
// Signs in anonymously (Firebase Auth), resolves the code through
// inviteCodes/{code}, then joins the group with the code as `joinCode`; the
// Firestore rules check it. The Firebase config comes from Firebase
// Hosting's reserved /__/firebase/init.json, so no key lives in this repo.
//
// All user content (trip names, idea titles, names) is set with
// textContent, never as HTML.

import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
import {
  getAuth, onAuthStateChanged, signInAnonymously,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";
import {
  getFirestore, doc, getDoc, setDoc, updateDoc, collection, onSnapshot,
  arrayUnion, arrayRemove, serverTimestamp,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";

// ---------------------------------------------------------------- strings

const lang = (navigator.language || "de").toLowerCase().startsWith("de") ? "de" : "en";
document.documentElement.lang = lang;

const STRINGS = {
  de: {
    invites: (n) => `${n} lädt dich ein`,
    invitedYou: "Du bist eingeladen",
    trip: "Reise",
    nameLabel: "Wie heißt du?",
    namePlaceholder: "Lea",
    nameMissing: "Gib deinen Namen ein.",
    join: "Mitmachen, ohne App",
    joining: "Einen Moment …",
    appHint: "Die TripFam-App kommt bald in den App Store.",
    members: (n) => (n === 1 ? "1 Person ist dabei" : `${n} Personen sind dabei`),
    ideas: "Worauf hast du Lust?",
    ideasEmpty: "Noch keine Ideen. Sobald jemand in der App etwas vorschlägt, erscheint es hier.",
    polls: "Abstimmungen",
    likes: (n) => (n === 1 ? "1 will hin" : `${n} wollen hin`),
    like: "Will ich",
    unlike: "Doch nicht",
    joined: "Du bist dabei. Deine Likes sieht die ganze Gruppe.",
    invalidTitle: "Diese Einladung gibt es nicht",
    invalidBody: "Prüf den Link oder frag nach einem neuen Code.",
    closedTitle: "Gerade läuft eine Abstimmung",
    closedBody: "Während die Gruppe swipt, kann niemand beitreten. Versuch es gleich noch einmal.",
    retry: "Noch einmal versuchen",
    errorTitle: "Das hat nicht geklappt",
    errorBody: "Prüf deine Internetverbindung und versuch es noch einmal.",
    nights: (a, b) => `${a} – ${b}`,
  },
  en: {
    invites: (n) => `${n} invites you`,
    invitedYou: "You're invited",
    trip: "Trip",
    nameLabel: "What's your name?",
    namePlaceholder: "Lea",
    nameMissing: "Enter your name.",
    join: "Join, no app needed",
    joining: "One moment…",
    appHint: "The TripFam app is coming to the App Store soon.",
    members: (n) => (n === 1 ? "1 person has joined" : `${n} people have joined`),
    ideas: "What do you fancy?",
    ideasEmpty: "No ideas yet. As soon as someone suggests something in the app, it shows up here.",
    polls: "Polls",
    likes: (n) => (n === 1 ? "1 wants to go" : `${n} want to go`),
    like: "I'm in",
    unlike: "Not for me",
    joined: "You're in. The whole group sees your likes.",
    invalidTitle: "This invite doesn't exist",
    invalidBody: "Check the link or ask for a new code.",
    closedTitle: "A vote is running right now",
    closedBody: "Nobody can join while the group is swiping. Try again in a moment.",
    retry: "Try again",
    errorTitle: "That didn't work",
    errorBody: "Check your connection and try again.",
    nights: (a, b) => `${a} – ${b}`,
  },
};
const t = STRINGS[lang];

// ---------------------------------------------------------------- dom helpers

/** Element with attributes and children; strings become text nodes. */
function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k === "class") el.className = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    // CSSOM, not the style attribute: the page CSP blocks inline styles.
    else if (k === "style") el.style.cssText = v;
    else el.setAttribute(k, v === true ? "" : String(v));
  }
  for (const c of children.flat()) {
    if (c == null || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

/** Inline stroke icon; markup is constant, never user data. */
function icon(name) {
  const paths = {
    heart: '<path d="M8 13.5S1.5 9.6 1.5 5.4A3.3 3.3 0 0 1 8 3.8a3.3 3.3 0 0 1 6.5 1.6C14.5 9.6 8 13.5 8 13.5z" fill="currentColor"/>',
    link: '<path d="M10 14l4-4m-5.5-1.5L7 10a3.5 3.5 0 0 0 5 5l1.5-1.5M15.5 10.5 17 9a3.5 3.5 0 0 0-5-5l-1.5 1.5" stroke="currentColor" stroke-width="1.8" fill="none" stroke-linecap="round"/>',
    pause: '<path d="M9 6v12M15 6v12" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
    alert: '<path d="M12 7v6m0 3.5v.5" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.8" fill="none"/>',
  };
  const box = name === "heart" ? "0 0 16 16" : "0 0 24 24";
  const span = document.createElement("span");
  span.setAttribute("aria-hidden", "true");
  span.innerHTML = `<svg viewBox="${box}">${paths[name]}</svg>`;
  return span.firstChild;
}

const app = document.getElementById("app");
function show(...nodes) {
  // Optional parts are passed as null; replaceChildren would print "null".
  app.replaceChildren(...nodes.filter((n) => n != null && n !== false));
}

function brand() {
  return h("div", { class: "brand" },
    h("img", { src: "/icon.png", alt: "" }),
    h("span", {}, h("span", { class: "trip" }, "trip"), h("span", { class: "fam" }, "fam")));
}

function message(iconName, title, body, action) {
  show(
    brand(),
    h("div", { class: "center" },
      h("div", {},
        h("div", { class: "badge" }, icon(iconName)),
        h("h1", { style: "font-size:24px;margin-top:16px" }, title),
        h("p", { class: "sub" }, body))),
    action ? h("div", { class: "footer" }, action) : null,
  );
}

function initials(name) {
  return (name || "?").trim().charAt(0).toUpperCase() || "?";
}

function formatDay(ts) {
  if (!ts?.toDate) return null;
  return ts.toDate().toLocaleDateString(lang === "de" ? "de-DE" : "en-GB", {
    day: "numeric", month: "short",
  });
}

// ---------------------------------------------------------------- firebase

const code = (location.pathname.match(/\/join\/([A-Za-z0-9]{4,12})\/?$/) || [])[1]?.toUpperCase();

let db;
let auth;

async function boot() {
  if (!code) {
    message("link", t.invalidTitle, t.invalidBody);
    return;
  }
  const config = await fetch("/__/firebase/init.json").then((r) => {
    if (!r.ok) throw new Error("no firebase config");
    return r.json();
  });
  const fb = initializeApp(config);
  auth = getAuth(fb);
  db = getFirestore(fb);

  // Reuse the anonymous account of an earlier visit from this browser.
  const user = await new Promise((resolve) => {
    const stop = onAuthStateChanged(auth, (u) => { stop(); resolve(u); });
  });
  if (!user) await signInAnonymously(auth);
  await openInvite();
}

async function openInvite() {
  const invite = await getDoc(doc(db, "inviteCodes", code));
  const groupId = invite.data()?.groupId;
  if (!invite.exists() || typeof groupId !== "string") {
    message("link", t.invalidTitle, t.invalidBody);
    return;
  }
  // Already a member (came back to the link): straight to the trip.
  try {
    const group = await getDoc(doc(db, "groups", groupId));
    if (group.exists()) {
      showTrip(groupId, group.data());
      return;
    }
  } catch (e) {
    if (e?.code !== "permission-denied") throw e;
  }
  showJoin(groupId, invite.data());
}

function showJoin(groupId, invite) {
  const owner = invite.ownerName;
  const input = h("input", {
    id: "guest-name", type: "text", autocomplete: "given-name",
    placeholder: t.namePlaceholder, maxlength: "40", enterkeyhint: "go",
  });
  const error = h("p", { class: "error", role: "alert", hidden: true });
  const button = h("button", { class: "primary", type: "submit" }, t.join);

  async function submit(event) {
    event.preventDefault();
    const name = input.value.trim();
    if (!name) {
      error.textContent = t.nameMissing;
      error.hidden = false;
      input.focus();
      return;
    }
    error.hidden = true;
    button.disabled = true;
    button.textContent = t.joining;
    try {
      await join(groupId, name);
    } catch (e) {
      button.disabled = false;
      button.textContent = t.join;
      if (e?.code === "permission-denied") {
        message("pause", t.closedTitle, t.closedBody,
          h("button", { class: "primary", onclick: () => openInvite() }, t.retry));
      } else {
        error.textContent = t.errorBody;
        error.hidden = false;
      }
    }
  }
  input.addEventListener("input", () => { error.hidden = true; });

  show(
    brand(),
    h("div", { class: "inviter" },
      h("div", { class: "avatar" }, initials(owner)),
      owner ? t.invites(owner) : t.invitedYou),
    h("div", {},
      h("h1", {}, invite.title || t.trip),
      invite.cityName ? h("p", { class: "sub" }, invite.cityName) : null),
    h("form", { onsubmit: submit, novalidate: true },
      h("label", { for: "guest-name" }, t.nameLabel),
      input,
      error,
      h("div", { class: "footer", style: "margin-top:20px" },
        button,
        h("p", { class: "hint" }, t.appHint))),
  );
  input.focus();
}

async function join(groupId, name) {
  const uid = auth.currentUser.uid;
  // A profile, so the app shows the name instead of "Mitglied 3".
  await setDoc(doc(db, "users", uid), {
    uid,
    email: "",
    displayName: name,
    favorites: [],
    groups: [],
    webGuest: true,
    createdAt: serverTimestamp(),
  }, { merge: true });
  await updateDoc(doc(db, "groups", groupId), {
    members: arrayUnion(uid),
    joinCode: code,
  });
  const group = await getDoc(doc(db, "groups", groupId));
  showTrip(groupId, group.data());
}

// ---------------------------------------------------------------- trip view

const placeCache = new Map();
async function placeImage(placeId) {
  if (!placeId) return null;
  if (!placeCache.has(placeId)) {
    placeCache.set(placeId, getDoc(doc(db, "places", placeId))
      .then((s) => s.data()?.imageUrls?.[0] ?? null)
      .catch(() => null));
  }
  return placeCache.get(placeId);
}

function showTrip(groupId, group) {
  const uid = auth.currentUser.uid;
  const start = formatDay(group.tripStart);
  const end = formatDay(group.tripEnd);
  const facts = [
    group.location?.cityName,
    start && end ? t.nights(start, end) : start,
    t.members((group.members || []).length),
  ].filter(Boolean).join(" · ");

  const ideasBox = h("div", { class: "group" });
  const pollsSection = h("section", { hidden: true },
    h("h2", { style: "margin-bottom:8px" }, t.polls));
  const pollsBox = h("div", { class: "group" });
  pollsSection.append(pollsBox);

  show(
    brand(),
    h("div", {},
      h("h1", {}, group.groupName || t.trip),
      h("p", { class: "sub" }, facts)),
    h("p", { class: "muted" }, t.joined),
    h("section", {},
      h("h2", { style: "margin-bottom:8px" }, t.ideas),
      ideasBox),
    pollsSection,
    h("div", { class: "footer" }, h("p", { class: "hint" }, t.appHint)),
  );

  const ideasRef = collection(db, "groups", groupId, "ideas");
  onSnapshot(ideasRef, (snap) => {
    const ideas = snap.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .sort((a, b) => (b.likedBy?.length || 0) - (a.likedBy?.length || 0));
    if (!ideas.length) {
      ideasBox.replaceChildren(h("div", { class: "row" },
        h("div", { class: "meta", style: "font-size:15px" }, t.ideasEmpty)));
      return;
    }
    ideasBox.replaceChildren(...ideas.map((idea) => ideaRow(groupId, idea, uid)));
  });

  onSnapshot(collection(db, "groups", groupId, "polls"), (snap) => {
    const polls = snap.docs.map((d) => ({ id: d.id, ...d.data() })).filter((p) => !p.closed);
    pollsSection.hidden = polls.length === 0;
    pollsBox.replaceChildren(...polls.map((poll) => pollBlock(groupId, poll, uid)));
  });
}

function ideaRow(groupId, idea, uid) {
  const liked = (idea.likedBy || []).includes(uid);
  const count = (idea.likedBy || []).length;
  const thumb = h("div", { class: "thumb" });
  placeImage(idea.placeId).then((url) => {
    if (url) thumb.style.backgroundImage = `url("${encodeURI(url)}")`;
  });
  const button = h("button", {
    class: "like", type: "button", "aria-pressed": liked ? "true" : "false",
    "aria-label": liked ? t.unlike : t.like,
    onclick: async () => {
      button.disabled = true;
      try {
        await updateDoc(doc(db, "groups", groupId, "ideas", idea.id), {
          likedBy: liked ? arrayRemove(uid) : arrayUnion(uid),
        });
      } finally {
        button.disabled = false;
      }
    },
  }, icon("heart"), String(count));
  return h("div", { class: "row" },
    thumb,
    h("div", { class: "text" },
      h("div", { class: "title" }, idea.title || ""),
      h("div", { class: "meta" }, t.likes(count))),
    button);
}

function pollBlock(groupId, poll, uid) {
  const votes = poll.votes || {};
  const total = Object.keys(votes).length;
  const mine = votes[uid];
  return h("div", { class: "poll" },
    h("div", { class: "q" }, poll.question || ""),
    ...(poll.options || []).map((option) => {
      const n = Object.values(votes).filter((v) => v === option.id).length;
      const share = total ? Math.round((n / total) * 100) : 0;
      return h("button", {
        class: "option", type: "button", "aria-pressed": mine === option.id ? "true" : "false",
        onclick: () => updateDoc(doc(db, "groups", groupId, "polls", poll.id), {
          [`votes.${uid}`]: option.id,
        }),
      },
      h("div", { class: "bar", style: `width:${share}%` }),
      h("span", {}, option.label || ""),
      h("span", {}, String(n)));
    }));
}

boot().catch((e) => {
  console.error(e);
  message("alert", t.errorTitle, t.errorBody,
    h("button", { class: "primary", onclick: () => location.reload() }, t.retry));
});
