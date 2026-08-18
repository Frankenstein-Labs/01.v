import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import BoardCardSessionBadge from 'ee/boards/components/board_card_session_badge.vue';
import BoardCardSessionBadgePopover from 'ee/boards/components/board_card_session_badge_popover.vue';
import getDuoAgentSessionsOnWorkItemQuery from 'ee/ai/shared/widgets/graphql/get_duo_agent_sessions_on_work_item.query.graphql';
import { SESSION_AWAITING_INPUT_GROUP } from 'ee/ai/shared/widgets/constants';
import { eventHub, SHOW_SESSION, SCROLL_TO_SESSIONS } from 'ee/ai/events/panel';

import {
  MOCK_ITEM,
  buildSession,
  buildQueryResponse,
  FINISHED_SESSION,
  RUNNING_SESSION,
  INPUT_REQUIRED_SESSION,
} from './board_card_session_badge_mock_data';

Vue.use(VueApollo);

describe('BoardCardSessionBadge', () => {
  let wrapper;
  let queryHandler;
  let apolloProvider;

  const createComponent = ({
    item = MOCK_ITEM,
    handler = queryHandler,
    duoAgentSessionsOnBoard = true,
  } = {}) => {
    apolloProvider = createMockApollo([[getDuoAgentSessionsOnWorkItemQuery, handler]]);
    wrapper = shallowMountExtended(BoardCardSessionBadge, {
      apolloProvider,
      propsData: { item },
      provide: {
        glFeatures: { duoAgentSessionsOnBoard },
      },
    });
  };

  const createWithSessions = async (nodes, { hasNextPage = false, ...opts } = {}) => {
    queryHandler = jest.fn().mockResolvedValue(buildQueryResponse({ nodes, hasNextPage }));
    createComponent(opts);
    await waitForPromises();
  };

  const findBadge = () => wrapper.findByTestId('board-card-session-badge');
  const findBadgeButton = () => wrapper.findByTestId('session-badge-button');
  const findBadgeCount = () => wrapper.findByTestId('session-badge-count');
  const findBadgeIcon = () => findBadgeButton().findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(BoardCardSessionBadgePopover);

  beforeEach(() => {
    queryHandler = jest.fn().mockResolvedValue(buildQueryResponse());
  });

  describe('when the feature flag is off', () => {
    beforeEach(() => {
      createComponent({ duoAgentSessionsOnBoard: false });
    });

    it('does not query and renders nothing', () => {
      expect(queryHandler).not.toHaveBeenCalled();
      expect(findBadge().exists()).toBe(false);
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ handler: jest.fn().mockReturnValue(new Promise(() => {})) });
    });

    it('renders nothing', () => {
      expect(findBadge().exists()).toBe(false);
    });
  });

  describe('when the query returns zero sessions', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders nothing', () => {
      expect(findBadge().exists()).toBe(false);
    });
  });

  describe('when sessions exist', () => {
    beforeEach(async () => {
      await createWithSessions([FINISHED_SESSION]);
    });

    it('renders the badge', () => {
      expect(findBadge().exists()).toBe(true);
    });

    it('passes item.id and first to the query', () => {
      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ id: MOCK_ITEM.id, first: 5 }),
      );
    });

    it('has js-no-trigger class', () => {
      expect(findBadge().classes()).toContain('js-no-trigger');
    });

    it('passes correct props to the popover component', () => {
      expect(findPopover().props()).toMatchObject({
        target: findBadgeButton().attributes('id'),
        sessions: [FINISHED_SESSION],
        isLoading: false,
        queryError: false,
        hasNextPage: false,
        displayCount: '1',
      });
    });
  });

  describe('when the query errors', () => {
    beforeEach(async () => {
      queryHandler = jest.fn().mockRejectedValue(new Error('GraphQL error'));
      createComponent();
      await waitForPromises();
    });

    it('renders the badge with "!" count', () => {
      expect(findBadge().exists()).toBe(true);
      expect(findBadgeCount().text()).toBe('!');
    });

    it('passes queryError=true to the popover', () => {
      expect(findPopover().props('queryError')).toBe(true);
    });

    it('refetches on retry via popover event', async () => {
      queryHandler.mockResolvedValueOnce(buildQueryResponse({ nodes: [FINISHED_SESSION] }));
      findPopover().vm.$emit('retry');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('with a single completed session', () => {
    beforeEach(async () => {
      await createWithSessions([FINISHED_SESSION]);
    });

    it('displays count "1" with neutral icon and singular aria-label', () => {
      expect(findBadgeCount().text()).toBe('1');
      expect(findBadgeIcon().props('variant')).toBe('subtle');
      expect(findBadgeButton().attributes('aria-label')).toBe(
        '1 Duo agent session. Activate to view.',
      );
    });
  });

  describe('with multiple non-awaiting sessions', () => {
    beforeEach(async () => {
      await createWithSessions([FINISHED_SESSION, RUNNING_SESSION]);
    });

    it('displays correct count with neutral icon and no pill', () => {
      expect(findBadgeCount().text()).toBe('2');
      expect(findBadgeIcon().props('variant')).toBe('subtle');
      expect(findBadgeButton().classes()).not.toContain('gl-rounded-pill');
    });
  });

  describe('with a session awaiting input', () => {
    beforeEach(async () => {
      await createWithSessions([FINISHED_SESSION, INPUT_REQUIRED_SESSION]);
    });

    it('uses warning icon with orange pill and attention label', () => {
      expect(findBadgeIcon().props('variant')).toBe('warning');
      expect(findBadgeButton().classes()).toContain('gl-rounded-pill');
      expect(findBadgeButton().classes()).toContain('session-badge-awaiting');
      expect(findBadgeButton().attributes('aria-label')).toContain('Attention required.');
    });
  });

  describe.each(SESSION_AWAITING_INPUT_GROUP.statuses)('with a session in %s status', (status) => {
    beforeEach(async () => {
      await createWithSessions([
        buildSession({
          id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/99',
          status,
          humanStatus: status,
        }),
      ]);
    });

    it('triggers warning variant', () => {
      expect(findBadgeIcon().props('variant')).toBe('warning');
    });
  });

  describe('with hasNextPage true', () => {
    beforeEach(async () => {
      const nodes = Array.from({ length: 5 }, (_, i) =>
        buildSession({ id: `gid://gitlab/Ai::DuoWorkflows::Workflow/${i + 1}` }),
      );
      await createWithSessions(nodes, { hasNextPage: true });
    });

    it('displays "5+" count and passes hasNextPage to popover', () => {
      expect(findBadgeCount().text()).toBe('5+');
      expect(findPopover().props('hasNextPage')).toBe(true);
      expect(findPopover().props('displayCount')).toBe('5+');
      expect(findBadgeButton().attributes('aria-label')).toContain('5+');
    });
  });

  describe('with hasNextPage false', () => {
    beforeEach(async () => {
      await createWithSessions([FINISHED_SESSION, RUNNING_SESSION]);
    });

    it('displays exact count and passes hasNextPage=false to popover', () => {
      expect(findBadgeCount().text()).toBe('2');
      expect(findPopover().props('hasNextPage')).toBe(false);
    });
  });

  describe('popover events', () => {
    beforeEach(async () => {
      await createWithSessions([FINISHED_SESSION]);
    });

    it('emits SHOW_SESSION on the eventHub when popover emits show-session', () => {
      const emitSpy = jest.spyOn(eventHub, '$emit');
      findPopover().vm.$emit('show-session', FINISHED_SESSION);

      expect(emitSpy).toHaveBeenCalledWith(SHOW_SESSION, { id: 1 });
      emitSpy.mockRestore();
    });

    it('emits view-all-sessions when popover emits view-all', () => {
      findPopover().vm.$emit('view-all');

      expect(wrapper.emitted('view-all-sessions')).toHaveLength(1);
    });

    it('emits SCROLL_TO_SESSIONS on the eventHub when popover emits view-all', () => {
      const emitSpy = jest.spyOn(eventHub, '$emit');
      findPopover().vm.$emit('view-all');

      expect(emitSpy).toHaveBeenCalledWith(SCROLL_TO_SESSIONS);
      emitSpy.mockRestore();
    });

    it('refetches the query when popover emits retry', async () => {
      queryHandler = jest.fn().mockRejectedValue(new Error('fail'));
      createComponent();
      await waitForPromises();

      queryHandler.mockResolvedValueOnce(buildQueryResponse({ nodes: [FINISHED_SESSION] }));
      findPopover().vm.$emit('retry');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(2);
    });
  });
});
