import { shallowMount } from '@vue/test-utils';
import { GlDrawer } from '@gitlab/ui';
import ExclusionFormDrawer from 'ee/security_configuration/secret_detection/components/exclusion_form_drawer.vue';
import ExclusionForm from 'ee/security_configuration/secret_detection/components/exclusion_form.vue';
import ExclusionDetails from 'ee/security_configuration/secret_detection/components/exclusion_details.vue';
import { DRAWER_MODES } from 'ee/security_configuration/secret_detection/constants';

describe('ExclusionFormDrawer', () => {
  let wrapper;

  const createComponent = ({ mode = DRAWER_MODES.ADD, exclusion = {}, stubs = {} } = {}) => {
    wrapper = shallowMount(ExclusionFormDrawer, {
      provide: {
        projectFullPath: 'group/project',
      },
      data() {
        return {
          isOpen: true,
          mode,
          exclusion,
        };
      },
      stubs,
    });
  };

  const findGlDrawer = () => wrapper.findComponent(GlDrawer);
  const findTitle = () => wrapper.find('h4');
  const findExclusionForm = () => wrapper.findComponent(ExclusionForm);
  const findExclusionDetails = () => wrapper.findComponent(ExclusionDetails);

  beforeEach(() => {
    createComponent();
  });

  it('renders the drawer', () => {
    expect(findGlDrawer().exists()).toBe(true);
  });

  it.each`
    mode                 | expectedTitle
    ${DRAWER_MODES.ADD}  | ${'Add exclusion'}
    ${DRAWER_MODES.EDIT} | ${'Update exclusion'}
    ${DRAWER_MODES.VIEW} | ${'Exclusion details'}
  `('sets the correct title for $mode mode', ({ mode, expectedTitle }) => {
    createComponent({ mode, stubs: { GlDrawer } });
    expect(findTitle().text()).toBe(expectedTitle);
  });

  it('renders ExclusionForm when not in VIEW mode', () => {
    expect(findExclusionForm().exists()).toBe(true);
    expect(findExclusionDetails().exists()).toBe(false);
  });

  it('renders ExclusionDetails in VIEW mode', () => {
    createComponent({ mode: DRAWER_MODES.VIEW });
    expect(findExclusionDetails().exists()).toBe(true);
    expect(findExclusionForm().exists()).toBe(false);
  });

  it('emits "updated" and closes the drawer when submit is called', async () => {
    await findExclusionForm().vm.$emit('saved');
    expect(wrapper.emitted('updated')).toEqual([[]]);

    expect(findGlDrawer().props('open')).toBe(false);
  });

  it('closes the drawer when close is called', async () => {
    await findExclusionForm().vm.$emit('cancel');
    expect(findGlDrawer().props('open')).toBe(false);
  });
});
