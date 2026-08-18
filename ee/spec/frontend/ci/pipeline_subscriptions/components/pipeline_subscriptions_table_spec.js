import { GlTable, GlLink } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PipelineSubscriptionsTable from 'ee/ci/pipeline_subscriptions/components/pipeline_subscriptions_table.vue';
import PipelineSubscriptionsForm from 'ee/ci/pipeline_subscriptions/components/pipeline_subscriptions_form.vue';
import { mockUpstreamSubscriptions } from '../mock_data';

describe('Pipeline Subscriptions Table', () => {
  let wrapper;

  const { count, nodes } = mockUpstreamSubscriptions.data.project.ciSubscriptionsProjects;

  const subscriptions = nodes.map((subscription) => {
    return {
      id: subscription.id,
      project: subscription.upstreamProject,
    };
  });

  const defaultProps = {
    count,
    subscriptions,
    emptyText: 'Empty',
    showActions: true,
    title: 'Subscriptions',
  };

  const findDeleteBtn = () => wrapper.findComponentByTestId('delete-subscription-btn');
  const findAddNewBtn = () => wrapper.findComponentByTestId('add-new-subscription-button');
  const findTitle = () => wrapper.findByTestId('crud-title');
  const findCount = () => wrapper.findByTestId('crud-count');
  const findNamespace = () => wrapper.findByTestId('subscription-namespace');
  const findProject = () => wrapper.findComponent(GlLink);
  const findTable = () => wrapper.findComponent(GlTable);
  const findForm = () => wrapper.findComponent(PipelineSubscriptionsForm);

  const createComponent = (props = defaultProps) => {
    wrapper = mountExtended(PipelineSubscriptionsTable, {
      propsData: {
        ...props,
      },
    });
  };

  it('displays title', () => {
    createComponent();

    expect(findTitle().text()).toContain(defaultProps.title);
  });

  it('displays count', () => {
    createComponent();

    expect(findCount().text()).toBe(String(defaultProps.count));
  });

  it('displays table', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });

  it('displays namespace', () => {
    createComponent();

    expect(findNamespace().text()).toBe(defaultProps.subscriptions[0].project.namespace.name);
  });

  it('displays project with link', () => {
    createComponent();

    expect(findProject().text()).toBe(defaultProps.subscriptions[0].project.name);
    expect(findProject().attributes('href')).toBe(defaultProps.subscriptions[0].project.webUrl);
  });

  it('emits subscription id when delete button is clicked', () => {
    createComponent();

    findDeleteBtn().vm.$emit('click');

    const expectedId = defaultProps.subscriptions[0].id;

    expect(wrapper.emitted('show-modal')).toEqual([[expectedId]]);
  });

  it.each`
    visible  | showActions
    ${true}  | ${true}
    ${false} | ${false}
  `(
    'should display actions: $visible when showActions prop is: $showActions',
    ({ visible, showActions }) => {
      createComponent({ ...defaultProps, showActions });

      expect(findDeleteBtn().exists()).toBe(visible);
      expect(findAddNewBtn().exists()).toBe(visible);
    },
  );

  it('does not display form', () => {
    createComponent();

    expect(findForm().exists()).toBe(false);
  });

  it('displays the form', async () => {
    createComponent();

    findAddNewBtn().vm.$emit('click');

    await nextTick();

    expect(findForm().exists()).toBe(true);
  });

  it('hides new button after intial click', async () => {
    createComponent();

    expect(findAddNewBtn().exists()).toBe(true);

    findAddNewBtn().vm.$emit('click');

    await nextTick();

    expect(findAddNewBtn().exists()).toBe(false);
  });
});
