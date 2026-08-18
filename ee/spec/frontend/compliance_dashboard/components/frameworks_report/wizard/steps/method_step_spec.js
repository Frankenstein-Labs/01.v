import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MethodStep from 'ee/compliance_dashboard/components/frameworks_report/wizard/steps/method_step.vue';

describe('MethodStep', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(MethodStep, {
      provide: {
        frameworkImportUrl: '/import',
      },
    });
  };

  const findBlankPanel = () => wrapper.findByTestId('method-blank_framework');
  const findTemplatePanel = () => wrapper.findByTestId('method-from_template');
  const findImportPanel = () => wrapper.findByTestId('method-import_framework');

  beforeEach(() => createComponent());

  it('renders the blank, from-template, and import panels', () => {
    expect(findBlankPanel().exists()).toBe(true);
    expect(findTemplatePanel().exists()).toBe(true);
    expect(findImportPanel().exists()).toBe(true);
  });

  it('emits select-blank when the blank panel is clicked', async () => {
    await findBlankPanel().trigger('click');

    expect(wrapper.emitted('select-blank')).toEqual([[]]);
  });

  it('emits select-template when the template panel is clicked', async () => {
    await findTemplatePanel().trigger('click');

    expect(wrapper.emitted('select-template')).toEqual([[]]);
  });
});
