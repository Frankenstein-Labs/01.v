import { GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import { mountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import { HTTP_STATUS_CREATED, HTTP_STATUS_UNPROCESSABLE_ENTITY } from '~/lib/utils/http_status';
import InitializerSection from 'ee/ai/duo_agents_platform/pages/onboarding/components/initializer_section.vue';

jest.mock('~/alert');

const SETUP_PATH = '/namespace/project/-/automate/onboarding/setup';

const defaultInitializers = () => [
  {
    event_type: 'init_project_context',
    display_name: 'Initialize project context',
    description: 'Create an AGENTS.md',
    target_file: 'AGENTS.md',
    applicable: true,
    skipped_reason: null,
    status: null,
    workflow_id: null,
  },
  {
    event_type: 'improve_ci',
    display_name: 'Improve CI setup',
    description: 'Improve the CI config',
    target_file: '.gitlab-ci.yml',
    applicable: false,
    skipped_reason: 'prerequisite_missing',
    status: null,
    workflow_id: null,
  },
  {
    event_type: 'init_execution_env',
    display_name: 'Initialize execution environment',
    description: 'Create agent-config.yml',
    target_file: '.gitlab/duo/agent-config.yml',
    applicable: true,
    skipped_reason: null,
    status: 'failed',
    workflow_id: 7,
  },
];

describe('InitializerSection', () => {
  let wrapper;
  let mockAxios;

  const createWrapper = ({ initializers = defaultInitializers(), runLabel } = {}) => {
    wrapper = mountExtended(InitializerSection, {
      propsData: {
        title: 'Customize agents for this project',
        anchorId: 'readiness-customize-agents',
        testid: 'customize-agents-section',
        initializers,
        setupPath: SETUP_PATH,
        runLabel,
      },
      mocks: {
        $router: {
          resolve: jest.fn(({ params }) => ({ href: `/sessions/${params.id}` })),
        },
      },
    });
  };

  const findRow = (eventType) =>
    extendedWrapper(wrapper.findByTestId(`initializer-row-${eventType}`));

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('rendering', () => {
    beforeEach(() => createWrapper());

    it('renders the section with a count of its items', () => {
      expect(wrapper.findByTestId('crud-count').text()).toContain('3');
    });

    it('renders a row for each initializer', () => {
      expect(findRow('init_project_context').exists()).toBe(true);
      expect(findRow('improve_ci').exists()).toBe(true);
      expect(findRow('init_execution_env').exists()).toBe(true);
    });

    it('shows a skipped badge and no action button for a non-applicable initializer', () => {
      const row = findRow('improve_ci');

      expect(row.findByTestId('skipped-badge').text()).toBe('Prerequisite missing');
      expect(row.findByTestId('action-button').exists()).toBe(false);
    });

    it('shows a "Generate" button (and no status badge) for an applicable not-started initializer', () => {
      const row = findRow('init_project_context');

      expect(row.findByTestId('action-button').text()).toBe('Generate');
      expect(row.findByTestId('status-badge').exists()).toBe(false);
    });

    it('shows a status badge, session link, and a "Retry" button for a failed initializer', () => {
      const row = findRow('init_execution_env');

      expect(row.findByTestId('status-badge').exists()).toBe(true);
      expect(row.findByTestId('session-link').attributes('href')).toBe('/sessions/7');
      expect(row.findByTestId('action-button').text()).toBe('Retry');
    });
  });

  describe('runLabel', () => {
    it('uses a custom run label when provided', () => {
      createWrapper({
        initializers: [defaultInitializers()[0]],
        runLabel: 'Improve CI',
      });

      expect(findRow('init_project_context').findByTestId('action-button').text()).toBe(
        'Improve CI',
      );
    });
  });

  describe('running an initializer', () => {
    describe('on success', () => {
      beforeEach(async () => {
        createWrapper();
        mockAxios.onPost(SETUP_PATH).reply(HTTP_STATUS_CREATED, { workflow_id: 101 });

        await findRow('init_project_context').findByTestId('action-button').trigger('click');
        await axios.waitForAll();
      });

      it('posts the initializer key to the setup path', () => {
        expect(mockAxios.history.post[0].url).toBe(SETUP_PATH);
        expect(JSON.parse(mockAxios.history.post[0].data)).toEqual({
          event_type: 'init_project_context',
        });
      });

      it('updates the row with status and a session link, and hides the run button', () => {
        const row = findRow('init_project_context');

        expect(row.findByTestId('status-badge').exists()).toBe(true);
        expect(row.findByTestId('session-link').attributes('href')).toBe('/sessions/101');
        expect(row.findByTestId('action-button').exists()).toBe(false);
      });
    });

    describe('retrying a failed initializer', () => {
      beforeEach(async () => {
        createWrapper();
        mockAxios.onPost(SETUP_PATH).reply(HTTP_STATUS_CREATED, { workflow_id: 202 });

        await findRow('init_execution_env').findByTestId('action-button').trigger('click');
        await axios.waitForAll();
      });

      it('posts the retried initializer key', () => {
        expect(JSON.parse(mockAxios.history.post[0].data)).toEqual({
          event_type: 'init_execution_env',
        });
      });

      it('updates the row to the new workflow session', () => {
        expect(findRow('init_execution_env').findByTestId('session-link').attributes('href')).toBe(
          '/sessions/202',
        );
      });
    });

    describe('on error', () => {
      beforeEach(async () => {
        createWrapper();
        mockAxios.onPost(SETUP_PATH).reply(HTTP_STATUS_UNPROCESSABLE_ENTITY, {
          message: 'something went wrong',
        });

        await findRow('init_project_context').findByTestId('action-button').trigger('click');
        await axios.waitForAll();
      });

      it('calls createAlert with the error message', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({ message: 'something went wrong' }),
        );
      });
    });

    it('disables the button while a run is in flight so it cannot start twice', async () => {
      createWrapper();
      mockAxios.onPost(SETUP_PATH).reply(HTTP_STATUS_CREATED, { workflow_id: 303 });

      findRow('init_project_context').findByTestId('action-button').trigger('click');
      await nextTick();

      expect(findRow('init_project_context').findComponent(GlButton).props('loading')).toBe(true);

      await axios.waitForAll();
    });
  });
});
