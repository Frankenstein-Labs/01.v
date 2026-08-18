import { GlButton, GlLabel, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ComplianceFrameworksToggleList from 'ee/security_orchestration/components/scope/compliance_frameworks_toggle_list.vue';
import { complianceFrameworksResponse as defaultNodes } from 'ee_jest/security_orchestration/mocks/mock_apollo';

jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: jest.fn((prefix) => `${prefix}_unique_id`),
}));

describe('ComplianceFrameworksToggleList', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ComplianceFrameworksToggleList, {
      propsData: {
        complianceFrameworks: defaultNodes,
        ...propsData,
      },
    });
  };

  const findAllButtons = () => wrapper.findAllComponents(GlButton);
  const findAllLabels = () => wrapper.findAllComponents(GlLabel);
  const findAllPopovers = () => wrapper.findAllComponents(GlPopover);
  const findHeader = () => wrapper.findByTestId('compliance-frameworks-header');
  const findHiddenLabelText = () => wrapper.findByTestId('hidden-labels-text');

  describe('all frameworks', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should render all labels', () => {
      expect(findAllLabels().exists()).toBe(true);
      expect(findAllPopovers()).toHaveLength(defaultNodes.length);
      expect(findAllLabels()).toHaveLength(defaultNodes.length);
    });

    it('renders header for all compliance frameworks', () => {
      expect(findHeader().text()).toBe('2 projects which have compliance framework:');
    });

    it('sets the correct attributes on popovers', () => {
      const popovers = findAllPopovers();
      const labels = findAllLabels();

      defaultNodes.forEach((node, index) => {
        expect(labels.at(index).attributes('id')).toBe(`${node.id}_unique_id`);
        expect(popovers.at(index).props()).toMatchObject({
          title: node.name,
          target: `${node.id}_unique_id`,
        });

        expect(popovers.at(index).text()).toContain(node.description);
      });
    });

    it('sets correct attributes on the edit button', () => {
      const firstPopover = findAllPopovers().at(0);
      const editButton = firstPopover.findComponent(GlButton);
      expect(editButton.exists()).toBe(true);
      expect(editButton.attributes('href')).toBe('/edit/framework/1');
      expect(editButton.text()).toBe('Edit compliance framework');
    });

    it('does not render edit button when editPath is not provided', () => {
      expect(findAllButtons()).toHaveLength(3);
    });
  });

  describe('projects exceed page size', () => {
    it('renders correct label when project list is bigger then default page size', () => {
      createComponent({
        propsData: {
          defaultProjectPageSize: 2,
        },
      });

      expect(findHeader().text()).toBe('2+ projects which have compliance framework:');
    });
  });

  describe('single framework', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          complianceFrameworks: [defaultNodes[1]],
        },
      });
    });

    it('renders header for single compliance frameworks', () => {
      expect(findHeader().text()).toBe('1 project which has compliance framework:');
      expect(findAllLabels()).toHaveLength(1);
      expect(findAllPopovers()).toHaveLength(1);
    });
  });

  describe('partial rendered list', () => {
    const { length: DEFAULT_NODES_LENGTH } = defaultNodes;

    it.each`
      labelsToShow | expectedLength | expectedText
      ${2}         | ${2}           | ${'+ 2 more'}
      ${1}         | ${1}           | ${'+ 3 more'}
    `('can show only partial list', ({ labelsToShow, expectedLength, expectedText }) => {
      createComponent({
        propsData: {
          labelsToShow,
        },
      });

      expect(findAllLabels()).toHaveLength(expectedLength);
      expect(findHiddenLabelText().text()).toBe(expectedText);
    });

    it.each`
      labelsToShow           | expectedLength          | hiddenTextExist
      ${10}                  | ${DEFAULT_NODES_LENGTH} | ${false}
      ${undefined}           | ${DEFAULT_NODES_LENGTH} | ${false}
      ${NaN}                 | ${DEFAULT_NODES_LENGTH} | ${false}
      ${null}                | ${DEFAULT_NODES_LENGTH} | ${false}
      ${2}                   | ${2}                    | ${true}
      ${defaultNodes.length} | ${DEFAULT_NODES_LENGTH} | ${false}
    `(
      'shows full list if labelsToShow is more than total number of labels',
      ({ labelsToShow, expectedLength, hiddenTextExist }) => {
        createComponent({
          propsData: {
            labelsToShow,
          },
        });

        expect(findAllLabels()).toHaveLength(expectedLength);
        expect(findHiddenLabelText().exists()).toBe(hiddenTextExist);
      },
    );
  });
});
