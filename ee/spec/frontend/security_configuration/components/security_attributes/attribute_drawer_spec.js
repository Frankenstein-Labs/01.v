import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AttributeDrawer from 'ee/security_configuration/components/security_attributes/attribute_drawer.vue';
import SecurityAttributeForm from 'ee/security_configuration/components/security_attributes/attribute_form.vue';
import { DRAWER_MODES } from 'ee/security_configuration/components/security_attributes/constants';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';

describe('AttributeDrawer', () => {
  let wrapper;

  const attribute = { name: 'Attribute 1', color: '#fff', description: 'A attribute' };

  const createComponent = () => {
    wrapper = shallowMountExtended(AttributeDrawer, {
      stubs: {
        GlDrawer,
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findForm = () => wrapper.findComponent(SecurityAttributeForm);
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-btn');
  const findCancelButton = () => wrapper.findByTestId('cancel-btn');
  const findDeleteButton = () => wrapper.findByTestId('delete-btn');

  beforeEach(() => {
    createComponent();
    wrapper.vm.open(DRAWER_MODES.ADD, attribute);
  });

  it('renders GlDrawer open with correct props', () => {
    expect(findDrawer().exists()).toBe(true);
    expect(findDrawer().props()).toMatchObject({
      open: true,
      zIndex: DRAWER_Z_INDEX,
    });
  });

  it('renders AttributeForm with correct props', () => {
    expect(findForm().props()).toMatchObject({
      attribute,
      mode: DRAWER_MODES.ADD,
    });
  });

  it('renders submit and cancel buttons', () => {
    expect(findSubmitButton().exists()).toBe(true);
    expect(findCancelButton().exists()).toBe(true);
  });

  it('submits the form on save button click', async () => {
    wrapper.vm.$refs.form.onSubmit = jest.fn();
    findSubmitButton().vm.$emit('click');
    await waitForPromises();

    expect(wrapper.vm.$refs.form.onSubmit).toHaveBeenCalled();
  });

  it('emits save-attribute event when form is submitted', async () => {
    const newAttribute = { id: undefined, name: 'Attribute' };
    wrapper.findComponent(SecurityAttributeForm).vm.$emit('saved', newAttribute);

    await waitForPromises();

    expect(wrapper.emitted()).toEqual({ 'save-attribute': [[newAttribute]] });
  });

  it('does not render delete button in ADD mode', () => {
    expect(findDeleteButton().exists()).toBe(false);
  });
});
