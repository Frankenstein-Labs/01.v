import { GlButton, GlLabel } from '@gitlab/ui';
import AttributesCell from 'ee/security_inventory/components/attributes_cell.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockSecurityAttributesWithCategories } from 'ee_jest/security_configuration/components/security_attributes/mock_data';
import { VISIBLE_ATTRIBUTE_COUNT } from 'ee/security_inventory/constants';
import { mockProjects, mockSubgroups } from '../mock_data';

describe('AttributesCell', () => {
  let wrapper;

  const mockProject = mockProjects[0];
  const mockGroup = mockSubgroups[0];

  const createComponent = (props = {}, provide = { canManageAttributes: false }) => {
    wrapper = shallowMountExtended(AttributesCell, {
      provide,
      propsData: {
        ...props,
      },
    });
  };

  const findVisibleAttributes = () =>
    wrapper.findByTestId('visible-attributes').findAllComponents(GlLabel);
  const findOverflowAttribute = () => wrapper.findComponentByTestId('overflow-attribute');
  const findAllAttributes = () => wrapper.findByTestId('all-attributes');
  const findAddAttributesAction = () => wrapper.findComponent(GlButton);

  describe('project view', () => {
    describe(`with more than ${VISIBLE_ATTRIBUTE_COUNT} attributes`, () => {
      const attributeCount = VISIBLE_ATTRIBUTE_COUNT + 2;

      beforeEach(() => {
        createComponent({
          item: {
            ...mockProject,
            securityAttributes: {
              nodes: mockSecurityAttributesWithCategories.slice(0, attributeCount),
            },
          },
          index: 0,
        });
      });

      it(`renders the first ${VISIBLE_ATTRIBUTE_COUNT} attributes in the cell`, () => {
        expect(findVisibleAttributes()).toHaveLength(VISIBLE_ATTRIBUTE_COUNT);
      });

      it('renders the overflow attribute and the full list of attributes in popover', () => {
        expect(findOverflowAttribute().props('title')).toBe('+2 more');
        expect(findAllAttributes().findAllComponents(GlLabel)).toHaveLength(attributeCount);
      });
    });

    describe(`with ${VISIBLE_ATTRIBUTE_COUNT} or fewer attributes`, () => {
      const attributeCount = VISIBLE_ATTRIBUTE_COUNT;

      beforeEach(() => {
        createComponent({
          item: {
            ...mockProject,
            securityAttributes: {
              nodes: mockSecurityAttributesWithCategories.slice(0, attributeCount),
            },
          },
          index: 0,
        });
      });

      it('renders the attributes in the cell', () => {
        expect(findVisibleAttributes()).toHaveLength(VISIBLE_ATTRIBUTE_COUNT);
      });

      it('does not render the overflow attribute or popover', () => {
        expect(findOverflowAttribute().exists()).toBe(false);
        expect(findAllAttributes().exists()).toBe(false);
      });
    });

    it.each`
      description                                | canManageAttributes | editable
      ${'renders add attributes action'}         | ${true}             | ${true}
      ${'does not render add attributes action'} | ${true}             | ${false}
      ${'does not render add attributes action'} | ${false}            | ${true}
    `(
      '$description with canManageAttributes $canManageAttributes and editable $editable',
      ({ editable, canManageAttributes }) => {
        const item = {
          ...mockProject,
          securityAttributes: {
            nodes: [],
          },
        };

        createComponent(
          {
            editable,
            item,
            index: 0,
          },
          { canManageAttributes },
        );

        expect(wrapper.text().includes('+ Add attributes')).toBe(canManageAttributes && editable);

        if (canManageAttributes && editable) {
          findAddAttributesAction().vm.$emit('click');

          expect(wrapper.emitted('open-attributes-drawer')).toEqual([[item]]);
        }
      },
    );

    it('renders — with no attributes when canManageAttributes is false', () => {
      createComponent(
        {
          item: {
            ...mockProject,
            securityAttributes: {
              nodes: [],
            },
          },
          index: 0,
        },
        { canManageAttributes: false },
      );

      expect(wrapper.text()).toBe('—');
    });
  });

  describe('group view', () => {
    beforeEach(() => {
      createComponent({ item: mockGroup, index: 0 });
    });

    it('renders an empty cell', () => {
      expect(wrapper.text()).toBe('');
    });
  });
});
