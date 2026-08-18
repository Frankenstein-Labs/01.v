import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import DrawerRuleCreate from 'ee/approvals/components/rule_drawer/create_rule.vue';
import { stubComponent } from 'helpers/stub_component';
import RuleForm from 'ee/approvals/components/rules/rule_form.vue';

jest.mock('~/lib/utils/dom_utils', () => ({ getContentWrapperHeight: jest.fn() }));

const TEST_RULE = { id: 7 };
const TEST_HEADER_HEIGHT = '123px';

Vue.use(Vuex);

describe('Approvals DrawerRuleCreate', () => {
  let wrapper;
  let submitMock;
  let store;

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findForm = () => wrapper.findComponent(RuleForm);
  const findSaveChangeButton = () => wrapper.findComponentByTestId('save-approval-rule-button');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findHeader = () => wrapper.find('h2');

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = () => {
    submitMock = jest.fn();

    const RuleFormStub = stubComponent(RuleForm, { methods: { submit: submitMock } });
    const propsData = { isOpen: true };

    wrapper = shallowMountExtended(DrawerRuleCreate, {
      store: new Vuex.Store(store),
      stubs: {
        RuleForm: RuleFormStub,
        GlDrawer,
      },
      propsData,
    });
  };

  beforeEach(() => {
    store = { modules: { approvals: { state: { editRule: TEST_RULE } } } };
    getContentWrapperHeight.mockReturnValue(TEST_HEADER_HEIGHT);
    createComponent();
  });

  describe('drawer title', () => {
    it('renders the correct title when adding', () => {
      store = { modules: { approvals: { state: null } } };
      createComponent();

      expect(findHeader().text()).toBe('Add approval rule');
    });

    it('renders the correct title when editing', () => {
      expect(findHeader().text()).toBe('Edit approval rule');
    });
  });

  it('emits a close event when cancel button is clicked', () => {
    findCancelButton().vm.$emit('click');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  describe('without data', () => {
    beforeEach(() => {
      store = { modules: { approvals: { state: null } } };
      createComponent();
    });

    it('renders drawer', () => {
      expect(findDrawer().props()).toEqual(
        expect.objectContaining({
          open: true,
          headerHeight: TEST_HEADER_HEIGHT,
          zIndex: DRAWER_Z_INDEX,
        }),
      );
    });

    it('renders form', () => {
      expect(findForm().props()).toEqual(
        expect.objectContaining({
          defaultRuleName: '',
          initRule: null,
          isMrEdit: true,
        }),
      );
    });

    describe('when drawer emits ok', () => {
      it('submits form, shows/hides a loader', async () => {
        findDrawer().vm.$emit('ok', new Event('ok'));
        await nextTick();

        expect(findSaveChangeButton().props('loading')).toBe(true);
        expect(submitMock).toHaveBeenCalled();

        await waitForPromises();

        expect(findSaveChangeButton().props('loading')).toBe(false);
      });

      it('emits a tracking event', async () => {
        findDrawer().vm.$emit('ok', new Event('ok'));
        await nextTick();
        const { trackEventSpy } = bindInternalEventDocument(findSaveChangeButton().element);
        expect(trackEventSpy).toHaveBeenCalledWith('change_merge_request_approvals', {
          label: 'repository_settings',
        });
      });
    });
  });

  describe('with data', () => {
    it('renders form', () => {
      expect(findForm().props('initRule')).toEqual(TEST_RULE);
      expect(findForm().props('isMrEdit')).toEqual(true);
    });
  });

  describe('with approval suggestions', () => {
    beforeEach(() => {
      store = {
        modules: {
          approvals: { state: { editRule: { ...TEST_RULE, defaultRuleName: 'Coverage-Check' } } },
        },
      };

      createComponent();
    });

    it('renders the correct title', () => {
      expect(findHeader().text()).toBe('Add approval rule');
    });

    it('renders add rule drawer', () => {
      expect(findDrawer().props()).toEqual(
        expect.objectContaining({
          open: true,
          zIndex: DRAWER_Z_INDEX,
        }),
      );
    });

    it('renders form with defaultRuleName', () => {
      expect(findForm().props('defaultRuleName')).toBe('Coverage-Check');
      expect(findForm().exists()).toBe(true);
    });

    it('renders the form when passing in an existing rule', () => {
      expect(findForm().exists()).toBe(true);
      expect(findForm().props('initRule')).toEqual(store.modules.approvals.state.editRule);
    });
  });
});
