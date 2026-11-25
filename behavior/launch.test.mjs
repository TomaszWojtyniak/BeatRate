// Launch journeys: from a cold start to the first screen, headless and with zero network.
import assert from 'node:assert/strict';
import test from 'node:test';
import { createBehaviorSession, fixture } from './sdk.mjs';

function session(t, ...names) {
  const s = createBehaviorSession({ fixtures: names.map(fixture) });
  t.after(() => s.close());
  return s;
}

test('a first-time guest sees the explainer, continues, and is asked for consent on the tabs', async (t) => {
  const s = session(t, 'device.guest', 'catalog.discovery', 'music.undecided');
  await s.precondition('MusicExplainer');

  await s.do({ action: 'Continue', expectation: ({ name }) => assert.equal(name, 'AnalyticsConsent') });
  await s.do({
    action: 'AllowAnalytics',
    expectation: ({ name, state }) => {
      assert.equal(name, 'Tabs');
      assert.equal(state.analyticsConsent, true);
    },
  });
});

test('refused music access still enters the app', async (t) => {
  const s = session(t, 'device.guest', 'consent.given', 'catalog.discovery', 'music.refused');
  await s.precondition('MusicExplainer');

  await s.do({
    action: 'Continue',
    expectation: ({ name, state }) => {
      assert.equal(name, 'Tabs');
      assert.equal(state.isLoggedIn, false);
    },
  });
});

test('a revoked Apple ID logs out completely and enters as a guest', async (t) => {
  const s = session(t, 'device.signedIn', 'apple.revoked', 'catalog.discovery');

  await s.precondition('Tabs', ({ state }) => {
    assert.equal(state.isLoggedIn, false);
    assert.equal(state.hasPlayer, false);
  });
});

test('three failed fetches still enter the app', async (t) => {
  const s = session(t, 'device.guest', 'consent.given', 'db.sectionsFail', 'timing.slowRetry');

  await s.precondition('Splash', ({ state }) =>
    assert.deepEqual(state.retry, { attempt: 1, of: 3, reason: 'connectionError' }));
  await s.precondition('Tabs');
});

test('a lost login row is rebuilt from the keychain and the firebase session', async (t) => {
  const s = session(t, 'device.signedIn', 'login.rowLost', 'catalog.discovery');

  // userId stays unset: who the user is was read as the splash started, before the
  // row was rebuilt — as in the app before the migration.
  await s.precondition('Tabs', ({ state }) => {
    assert.equal(state.isLoggedIn, true);
    assert.equal(state.hasPlayer, true);
  });
});

test('a signed-in user without a player is sent to the picker', async (t) => {
  const s = session(t, 'device.signedIn', 'player.none', 'catalog.discovery');

  await s.precondition('PlayerPicker', ({ state }) => assert.equal(state.isLoggedIn, true));
});

test('a returning guest who answered before is not asked again', async (t) => {
  const s = session(t, 'device.guest', 'consent.given', 'catalog.discovery');

  await s.precondition('Tabs', ({ state }) => {
    assert.equal(state.isAskingAnalyticsConsent, false);
    assert.equal(state.analyticsConsent, true);
  });
});

test('an album without a music fixture ends the cli with code 3', async (t) => {
  const s = session(t, 'device.guest', 'consent.given', 'catalog.discovery', 'music.noAlbums');

  await assert.rejects(s.precondition('Tabs'), /exited with code 3: network violation: missing music fixture: album 1440935467/);
});
