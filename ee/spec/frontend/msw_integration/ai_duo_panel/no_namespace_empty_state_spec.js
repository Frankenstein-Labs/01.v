import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { waitFor, screen } from '@testing-library/vue';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { CHAT_MODES } from '~/super_sidebar/constants';
import { initDuoPanel } from 'ee/ai/init_duo_panel';

Vue.use(VueApollo);

// A Duo user with no default namespace opens the panel outside a group/project.
// Both `agenticAvailable` and `classicAvailable` are 'false' because that is what
// the backend sends here (the policies deny against a nil container) — the prompt
// must render anyway.
const PREFERENCES_PATH = '/-/profile/preferences';

const createDuoPanelElement = () => {
  const el = document.createElement('div');
  el.id = 'duo-chat-panel';
  Object.assign(el.dataset, {
    userId: 'gid://gitlab/User/1',
    agenticAvailable: 'false',
    classicAvailable: 'false',
    defaultNamespaceSelected: 'false',
    isSaas: 'true',
    preferencesPath: PREFERENCES_PATH,
    autoExpand: 'true',
  });
  document.body.appendChild(el);
  return el;
};

describe('AI panel when a default namespace is required', () => {
  useLocalStorageSpy();

  const findNoNamespaceEmptyState = () => screen.queryByTestId('no-namespace-empty-state');
  const findPreferencesButton = () => screen.queryByTestId('go-to-preferences-button');
  const findReturnToClassicButton = () =>
    screen.queryByRole('button', { name: /return to non-agentic chat/i });
  const findAgenticModeToggle = () => screen.queryByRole('switch', { name: /agentic/i });

  const mountPanel = () => {
    createDuoPanelElement();
    initDuoPanel();
  };

  const clearPanelStorage = () => {
    window.sessionStorage.clear();
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
    duoChatGlobalState.lastRoutePerTab = {};
  };

  beforeEach(() => {
    document.body.innerHTML = '';
    clearPanelStorage();
  });

  afterEach(() => {
    clearPanelStorage();
  });

  it('renders the no-namespace empty state with a working preferences link', async () => {
    mountPanel();

    await waitFor(() => {
      expect(findNoNamespaceEmptyState()).not.toBeNull();
    });

    expect(findPreferencesButton()).not.toBeNull();
    expect(findPreferencesButton().getAttribute('href')).toBe(PREFERENCES_PATH);
  });

  it('does not render a return-to-classic button or the agentic toggle', async () => {
    mountPanel();

    await waitFor(() => {
      expect(findNoNamespaceEmptyState()).not.toBeNull();
    });

    expect(findReturnToClassicButton()).toBeNull();
    expect(findAgenticModeToggle()).toBeNull();
  });
});
