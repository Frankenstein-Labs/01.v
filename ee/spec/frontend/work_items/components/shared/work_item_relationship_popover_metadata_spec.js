import { GlIcon, GlTooltip } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import WorkItemPopoverMetadata from 'ee/work_items/components/shared/work_item_relationship_popover_metadata.vue';
import { workItemTaskEE } from '../../mock_data';

describe('WorkItemPopoverMetadataEE', () => {
  const mockWeight = workItemTaskEE.widgets.find((widget) => widget.type === 'WEIGHT');
  const mockIteration = workItemTaskEE.widgets.find((widget) => widget.type === 'ITERATION');

  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(WorkItemPopoverMetadata, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        workItem: workItemTaskEE,
        workItemFullPath: 'gitlab-org/gitlab-test',
      },
    });
  };

  const findIteration = () => wrapper.findByTestId('item-iteration');
  const findWeight = () => wrapper.findByTestId('item-weight');
  const findDates = () => wrapper.findByTestId('item-dates');
  const findWeightValue = () => wrapper.findByTestId('weight-value');
  const findIterationCadence = () => wrapper.findByTestId('iteration-cadence');
  const findIterationTitle = () => wrapper.findByTestId('iteration-title');
  const findIterationName = () => wrapper.findByTestId('iteration-name');
  const findIterationPeriod = () => wrapper.findByTestId('iteration-period');
  const findIterationValue = () => wrapper.findByTestId('iteration-value');

  beforeEach(() => {
    createComponent();
  });

  it('renders item weight icon and value', () => {
    expect(findWeight().exists()).toBe(true);
    expect(findWeight().findComponent(GlIcon).props('name')).toBe('weight');
    expect(findWeightValue().text()).toContain(`${mockWeight.weight}`);
  });

  it('renders item iteration icon and name', () => {
    expect(findIteration().exists()).toBe(true);
    expect(findIteration().findComponent(GlIcon).props('name')).toBe('iteration');
    expect(findIterationPeriod().text()).toContain('Dec 19, 2023 – Jan 15, 2024');
  });

  it('renders item start and due dates icon and text', () => {
    expect(findDates().exists()).toBe(true);
    expect(findDates().findComponent(GlIcon).props('name')).toBe('calendar');
    expect(findDates().text()).toContain('Jan 1 – Jun 27, 2024');
  });

  it('renders gl-tooltip', () => {
    expect(findIteration().findComponent(GlTooltip).isVisible()).toBe(true);
    expect(findIterationTitle().text()).toContain('Iteration');
  });

  it('renders iteration tooltip text', () => {
    expect(findIterationCadence().text()).toContain(
      `${mockIteration.iteration.iterationCadence.title}`,
    );
    expect(findIterationName().text()).toContain(`${mockIteration.iteration.title}`);
    expect(findIterationValue().text()).toContain('Dec 19, 2023 – Jan 15, 2024');
  });
});
