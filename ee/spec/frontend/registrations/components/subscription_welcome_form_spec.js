import { GlForm, GlFormFields } from '@gitlab/ui';
import { nextTick } from 'vue';
import SubscriptionWelcomeForm from 'ee/registrations/components/subscription_welcome_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('SubscriptionWelcomeForm', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMountExtended(SubscriptionWelcomeForm, {
      propsData: {
        userData: {
          firstName: '',
          lastName: '',
          showNameFields: false,
          companyName: '',
          groupName: '',
          projectName: '',
        },
        submitPath: '/subscriptions/welcome',
        namespaceId: null,
        serverValidations: {},
        ...props,
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findCompanyInput = () => wrapper.findComponentByTestId('company-name');
  const fieldsProps = () => findFormFields().props('fields');
  const hiddenFirstName = () => wrapper.findByTestId('hidden-first-name');
  const hiddenLastName = () => wrapper.findByTestId('hidden-last-name');

  describe('form initialization', () => {
    it('initializes form values from props', () => {
      wrapper = createComponent({
        userData: {
          firstName: 'John',
          lastName: 'Doe',
          showNameFields: true,
          companyName: 'Test Corp',
          groupName: 'test-group',
          projectName: 'test-project',
        },
        namespaceId: 123,
      });

      expect(wrapper.vm.formValues).toEqual({
        first_name: 'John',
        last_name: 'Doe',
        company_name: 'Test Corp',
        group_name: 'test-group',
        project_name: 'test-project',
        namespace_id: 123,
      });
    });

    it('renders form with correct attributes', () => {
      wrapper = createComponent();

      expect(findForm().attributes('action')).toBe('/subscriptions/welcome');
      expect(findForm().attributes('method')).toBe('post');
      expect(findForm().attributes('id')).toBe('subscription-welcome-form');
    });

    it('includes CSRF and method override tokens', () => {
      wrapper = createComponent();

      expect(wrapper.find('input[name="authenticity_token"]').exists()).toBe(true);
      expect(wrapper.find('input[name="_method"]').attributes('value')).toBe('patch');
    });
  });

  describe('field configuration', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('configures company_name field as required', () => {
      expect(fieldsProps().company_name.label).toBe('Company name');
      expect(fieldsProps().company_name.validators).toHaveLength(1);
    });

    it('configures group_name field as required when no namespaceId', () => {
      expect(fieldsProps().group_name.inputAttrs.disabled).toBe(false);
      expect(fieldsProps().group_name.validators).toHaveLength(1);
    });

    it('disables group_name field when namespaceId is provided', () => {
      wrapper = createComponent({ namespaceId: 123 });

      expect(fieldsProps().group_name.inputAttrs.disabled).toBe(true);
      expect(fieldsProps().group_name.validators).toHaveLength(0);
    });

    it('configures project_name field as required', () => {
      expect(fieldsProps().project_name.validators).toHaveLength(1);
    });

    it('hides namespace_id field', () => {
      expect(fieldsProps().namespace_id.groupAttrs.class).toBe('gl-hidden');
    });

    describe('name fields', () => {
      it('includes first_name and last_name fields when showNameFields is true', () => {
        wrapper = createComponent({ userData: { showNameFields: true } });

        const props = fieldsProps();

        expect(props.first_name.label).toBe('First name');
        expect(props.first_name.validators).toHaveLength(1);
        expect(props.last_name.label).toBe('Last name');
        expect(props.last_name.validators).toHaveLength(1);
        expect(hiddenFirstName().exists()).toBe(false);
        expect(hiddenLastName().exists()).toBe(false);
      });

      it('excludes first_name and last_name fields when showNameFields is false', () => {
        wrapper = createComponent({
          userData: {
            firstName: 'John',
            lastName: 'Doe',
            showNameFields: false,
          },
        });

        const props = fieldsProps();
        const firstName = hiddenFirstName();
        const lastName = hiddenLastName();

        expect(props).not.toHaveProperty('first_name');
        expect(props).not.toHaveProperty('last_name');
        expect(firstName.exists()).toBe(true);
        expect(firstName.attributes('value')).toBe('John');
        expect(lastName.exists()).toBe(true);
        expect(lastName.attributes('value')).toBe('Doe');
      });
    });
  });

  describe('field validations', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it.each`
      value       | isValid
      ${''}       | ${false}
      ${null}     | ${false}
      ${'TestCo'} | ${true}
    `('validates company_name: "$value" -> $isValid', ({ value, isValid }) => {
      const validator = fieldsProps().company_name.validators[0];
      const result = validator(value);
      expect(Boolean(result)).toBe(!isValid);
    });

    it.each`
      value              | isValid
      ${''}              | ${false}
      ${null}            | ${false}
      ${'My Test Group'} | ${true}
    `('validates group_name: "$value" -> $isValid', ({ value, isValid }) => {
      const validator = fieldsProps().group_name.validators[0];
      const result = validator(value);
      expect(Boolean(result)).toBe(!isValid);
    });

    it.each`
      value                | isValid
      ${''}                | ${false}
      ${null}              | ${false}
      ${'My Test Project'} | ${true}
    `('validates project_name: "$value" -> $isValid', ({ value, isValid }) => {
      const validator = fieldsProps().project_name.validators[0];
      const result = validator(value);
      expect(Boolean(result)).toBe(!isValid);
    });
  });

  describe('company name auto-population', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('updates group and project names when company name changes', async () => {
      findCompanyInput().vm.$emit('input', 'Acme Corp');
      await nextTick();

      expect(wrapper.vm.formValues.group_name).toBe('Acme Corp-group');
      expect(wrapper.vm.formValues.project_name).toBe('Acme Corp-project');
    });

    it('clears group and project names when company name is cleared', async () => {
      wrapper.vm.formValues.company_name = 'Test Corp';
      await nextTick();

      findCompanyInput().vm.$emit('input', '');
      await nextTick();

      expect(wrapper.vm.formValues.group_name).toBe('');
      expect(wrapper.vm.formValues.project_name).toBe('');
    });
  });

  describe('server validations', () => {
    it('passes server validations to form fields', () => {
      const serverValidations = { company_name: ['Already exists'] };
      wrapper = createComponent({ serverValidations });

      expect(findFormFields().props('serverValidations')).toEqual(serverValidations);
    });
  });
});
