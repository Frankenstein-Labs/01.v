import { GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import {
  FIX_AVAILABLE,
  FALSE_POSITIVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import AttributeFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filter.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('AttributeFilter', () => {
  let wrapper;

  const initialProps = {
    attribute: FALSE_POSITIVE,
    operatorValue: true,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AttributeFilter, {
      propsData: {
        ...initialProps,
        ...props,
      },
      stubs: {
        SectionLayout,
        GlCollapsibleListbox,
        GlIcon,
      },
    });
  };

  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findOperatorValueSelect = () =>
    wrapper.findComponentByTestId('vulnerability-attribute-operator-select');
  const findAttributeSelect = () => wrapper.findComponentByTestId('vulnerability-attribute-select');
  const findInformationIcon = () => wrapper.findComponent(GlIcon);

  it('renders initial dropdowns', () => {
    createComponent();

    expect(findOperatorValueSelect().exists()).toBe(true);
    expect(findAttributeSelect().exists()).toBe(true);
  });

  it.each`
    attribute         | shouldExist
    ${FIX_AVAILABLE}  | ${true}
    ${FALSE_POSITIVE} | ${false}
  `('renders information icon conditionally based on attribute', ({ attribute, shouldExist }) => {
    createComponent({ attribute });

    expect(findInformationIcon().exists()).toBe(shouldExist);
  });

  it.each`
    disabled
    ${true}
    ${false}
  `('can set attribute dropdown as disabled', ({ disabled }) => {
    createComponent({ disabled });

    expect(findAttributeSelect().props('disabled')).toBe(disabled);
  });

  it('emits input event when setting an operator value', async () => {
    createComponent();

    await findOperatorValueSelect().vm.$emit('select', 'false');

    expect(wrapper.emitted('input')).toEqual([[false]]);
  });

  it('emits attribute-change event when setting attribute', async () => {
    createComponent();

    await findAttributeSelect().vm.$emit('select', FIX_AVAILABLE);

    expect(wrapper.emitted('attribute-change')).toEqual([[FIX_AVAILABLE]]);
  });

  it('emits remove event', async () => {
    createComponent();

    await findSectionLayout().vm.$emit('remove');

    expect(wrapper.emitted('remove')).toEqual([[FALSE_POSITIVE]]);
  });

  it.each`
    showRemoveButton | expected
    ${true}          | ${true}
    ${false}         | ${false}
    ${undefined}     | ${true}
  `(
    'sets showRemoveButton prop to $expected when showRemoveButton is $showRemoveButton',
    ({ showRemoveButton, expected }) => {
      createComponent({ showRemoveButton });

      expect(findSectionLayout().props('showRemoveButton')).toBe(expected);
    },
  );
});
