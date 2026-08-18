import { waitFor } from '@testing-library/vue';
import { getText, waitForElement } from 'ee_jest/msw_integration/test_helpers';
import { SIDE_PANEL_ROUTE_CONTEXT } from 'ee/ai/duo_agents_platform/constants';
import { AGENTIC_CHAT_HISTORY_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { getStorageKey, saveRouteState } from 'ee/ai/duo_agents_platform/utils/navigation_state';
import {
  buildChatConfiguration,
  findDuoDisabledEmptyState,
  findDuoDisabledToggle,
  findDuoSettingsCta,
  findThreadListPanel,
  mountAISidebar,
  setupDuoChatTest,
  teardownDuoChatTest,
} from '../duo_agentic_chat/test_setup';

// Replaces the "shows the Duo disabled empty state with a link to Duo settings"
// example from the 'user sees agentic chat blocked state' shared example in
// ee/spec/support/shared_examples/ai/agentic_chat_shared_example.rb.
//
// Its sibling example — that the panel stays in whatever open/closed state the
// user left it in across a reload — is covered by
// panel_visibility_persistence_spec.js.

// The real stream_manager and stream_worker run; only the websocket transport
// is faked. Neither spec sends a prompt, so no socket is ever opened.

const DUO_SETTINGS_PATH = '/my-group/my-project/-/settings/gitlab_duo';

describe('AI panel when GitLab Duo is turned off for the container', () => {
  const mountBlockedPanel = () =>
    mountAISidebar({
      chatConfiguration: buildChatConfiguration({
        defaultProps: {
          isDuoDisabled: true,
          chatDisabledReason: 'project',
          shouldShowBlockedState: true,
          containerType: 'project',
          duoSettingsPath: DUO_SETTINGS_PATH,
        },
      }),
    });

  beforeEach(setupDuoChatTest);

  afterEach(() => teardownDuoChatTest());

  it('offers the blocked-state toggle instead of the usual chat tabs', async () => {
    mountBlockedPanel();

    await waitForElement(findDuoDisabledToggle);
  });

  it('explains how to turn Duo on and links to the settings page', async () => {
    mountBlockedPanel();

    const toggle = await waitForElement(findDuoDisabledToggle);
    toggle.click();

    await waitFor(() => {
      expect(findDuoDisabledEmptyState()).not.toBe(null);
    });

    expect(getText(findDuoDisabledEmptyState())).toContain('Turn on GitLab Duo Agent Platform');

    // The CTA points at the container's own Duo settings page.
    expect(findDuoSettingsCta().getAttribute('href')).toBe(DUO_SETTINGS_PATH);
    expect(getText(findDuoSettingsCta())).toBe('Go to Duo settings');
  });

  // The startup path, which no click reaches: the user was on the History tab
  // when Duo was turned off, so `restoreLastRoute` has to send the restored
  // session to the blocked view instead of replaying the saved route. History
  // specifically, because `AiPanel.mounted` redirects any restored *chat* route
  // to the blocked view on its own and would mask the router's decision.
  it('sends a restored session to the blocked state instead of the saved route', async () => {
    saveRouteState({ name: AGENTIC_CHAT_HISTORY_ROUTE }, getStorageKey(SIDE_PANEL_ROUTE_CONTEXT));

    mountBlockedPanel();

    await waitForElement(findDuoDisabledEmptyState);

    expect(findThreadListPanel()).toBe(null);
    expect(findDuoSettingsCta().getAttribute('href')).toBe(DUO_SETTINGS_PATH);
  });
});
