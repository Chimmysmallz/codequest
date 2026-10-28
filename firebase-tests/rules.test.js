// Firestore security-rules tests for CodeQuest.
//
// They run against the LOCAL Firebase emulator (no real project, no cost).
// From the project root:
//   1) cd firebase-tests, then install the packages listed in package.json
//      (npm i), then cd back to the project root
//   2) firebase emulators:exec --only firestore --project demo-codequest "npm --prefix firebase-tests test"
//
// They prove the "data lock": players can only touch their own progress,
// everyone signed in can read the leaderboard, nobody can write someone else's row.

import { readFileSync } from "node:fs";
import { test, before, after, beforeEach } from "node:test";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-codequest",
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

const progress = { xp: 120, coins: 300, completed: ["v1", "v2"] };

test("a player can save and read their own progress", async () => {
  const db = env.authenticatedContext("alice").firestore();
  await assertSucceeds(setDoc(doc(db, "users/alice"), progress));
  await assertSucceeds(getDoc(doc(db, "users/alice")));
});

test("a player cannot read another player's progress", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "users/bob"), progress);
  });
  const db = env.authenticatedContext("alice").firestore();
  await assertFails(getDoc(doc(db, "users/bob")));
});

test("a player cannot overwrite another player's progress", async () => {
  const db = env.authenticatedContext("alice").firestore();
  await assertFails(setDoc(doc(db, "users/bob"), { xp: 0 }));
});

test("signed-out visitors cannot read or write progress", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "users/alice")));
  await assertFails(setDoc(doc(db, "users/alice"), progress));
});

test("signed-in players can read the leaderboard", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "leaderboard/bob"), { name: "Bob", xp: 500 });
  });
  const db = env.authenticatedContext("alice").firestore();
  await assertSucceeds(getDoc(doc(db, "leaderboard/bob")));
});

test("signed-out visitors cannot read the leaderboard", async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "leaderboard/bob")));
});

test("a player can only write their own leaderboard row", async () => {
  const db = env.authenticatedContext("alice").firestore();
  await assertSucceeds(setDoc(doc(db, "leaderboard/alice"), { name: "Alice", xp: 100 }));
  await assertFails(setDoc(doc(db, "leaderboard/bob"), { name: "Hacked", xp: 99999 }));
});

test("every other collection is locked", async () => {
  const db = env.authenticatedContext("alice").firestore();
  await assertFails(setDoc(doc(db, "admin/settings"), { open: true }));
  await assertFails(getDoc(doc(db, "admin/settings")));
});
