import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { mount, ErrorWrapper } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';

import { createAlert } from '~/alert';
import { createComplianceFrameworksReportResponse } from 'ee_jest/compliance_dashboard/mock_data';
import getComplianceFrameworksCompactQuery from 'ee/compliance_dashboard/components/projects_report/graphql/get_compliance_frameworks_compact.query.graphql';
import FrameworkSelectionBox from 'ee/compliance_dashboard/components/projects_report/framework_selection_box.vue';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/alert');

Vue.use(VueApollo);
describe('FrameworkSelectionBox component', () => {
  let wrapper;
  let apolloProvider;

  const mockedResponse = createComplianceFrameworksReportResponse();
  // for testing filtering
  mockedResponse.data.namespace.complianceFrameworks.nodes[0].name = 'PCI-DSS';
  const getComplianceFrameworkQueryResponse = jest.fn().mockResolvedValue(mockedResponse);
  const framework = mockedResponse.data.namespace.complianceFrameworks.nodes[0];
  const findNewFrameworkButton = () =>
    wrapper
      .findAllComponents(GlButton)
      .wrappers.find((w) => w.text().includes(FrameworkSelectionBox.i18n.createNewFramework)) ??
    new ErrorWrapper();

  const createComponent = (props) => {
    apolloProvider = createMockApollo([
      [getComplianceFrameworksCompactQuery, getComplianceFrameworkQueryResponse],
    ]);

    wrapper = mount(FrameworkSelectionBox, {
      apolloProvider,
      propsData: {
        groupPath: 'group-path',
        isFrameworkCreatingEnabled: true,
        ...props,
      },
    });
  };

  beforeEach(() => {
    getComplianceFrameworkQueryResponse.mockClear();
  });

  it('sets underlying listbox as disabled when disabled prop is true', () => {
    createComponent({ disabled: true });

    expect(wrapper.findComponent(GlCollapsibleListbox).props('disabled')).toBe(true);
  });

  it('sets toggle-text as default one when selection is not provided', () => {
    createComponent();

    expect(wrapper.findComponent(GlCollapsibleListbox).props('toggleText')).toBe(
      FrameworkSelectionBox.i18n.frameworksDropdownPlaceholder,
    );
  });

  it('sets toggle-text to framework name when framework is selected', async () => {
    createComponent({ selected: [framework.id] });

    await waitForPromises();

    expect(wrapper.findComponent(GlCollapsibleListbox).props('toggleText')).toBe(framework.name);
  });

  it('sets toggle-text to placeholder when no framework is selected', async () => {
    createComponent({ selected: [] });

    await waitForPromises();

    expect(wrapper.findComponent(GlCollapsibleListbox).props('toggleText')).toBe(
      'Select frameworks',
    );
  });

  it('updates listbox prop selected when selection is changed', async () => {
    createComponent({ selected: [framework.id] });

    await nextTick();

    expect(wrapper.findComponent(GlCollapsibleListbox).props('selected')).toMatchObject([
      framework.id,
    ]);
  });

  it('emits selected framework from underlying listbox', () => {
    createComponent();

    wrapper.findComponent(GlCollapsibleListbox).vm.$emit('select', 'framework-id');
    expect(wrapper.emitted('select').at(-1)).toStrictEqual(['framework-id']);
  });

  it('emits update evenet with selected frameworks when the selection changed and user clicks outside', () => {
    createComponent();

    wrapper.findComponent(GlCollapsibleListbox).vm.$emit('select', 'framework-id-1');
    wrapper.findComponent(GlCollapsibleListbox).vm.$emit('hidden');
    expect(wrapper.emitted('update').at(-1)).toStrictEqual(['framework-id-1']);
  });
  it('does not emit update event when the selection have not changed', () => {
    createComponent();

    wrapper.findComponent(GlCollapsibleListbox).vm.$emit('select', []);
    wrapper.findComponent(GlCollapsibleListbox).vm.$emit('hidden');
    expect(wrapper.emitted('update')).toBeUndefined();
  });

  it('filters framework list for underlying listbox', async () => {
    createComponent();

    await waitForPromises();

    wrapper.findComponent(GlCollapsibleListbox).vm.$emit('search', 'PCI');
    await nextTick();

    // only "PCI-DSS" from fixture matches
    expect(wrapper.findComponent(GlCollapsibleListbox).props('items')).toHaveLength(1);
  });

  it('sets listbox to loading while loading list of elements', () => {
    createComponent();

    expect(wrapper.findComponent(GlCollapsibleListbox).props('loading')).toBe(true);
  });

  it('reports error to sentry', async () => {
    const ERROR = new Error('Network error');
    getComplianceFrameworkQueryResponse.mockRejectedValue(ERROR);

    createComponent();

    await waitForPromises();

    expect(captureException).toHaveBeenCalledWith(ERROR);
    expect(createAlert).toHaveBeenCalled();
  });

  it('has a new framework button', () => {
    createComponent();

    expect(findNewFrameworkButton().exists()).toBe(true);
  });

  it('clicking new framework button emits create event', () => {
    createComponent();

    findNewFrameworkButton().vm.$emit('click');

    expect(wrapper.emitted('create')).toHaveLength(1);
  });

  it('does not have a new framework button when framework editing disabled', () => {
    createComponent({ isFrameworkCreatingEnabled: false });

    expect(findNewFrameworkButton().exists()).toBe(false);
  });
});
