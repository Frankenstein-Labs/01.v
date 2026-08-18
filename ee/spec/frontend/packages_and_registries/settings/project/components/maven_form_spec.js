import { GlFormGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import MavenForm from 'ee_component/packages_and_registries/settings/project/components/maven_form.vue';
import { dependencyProxyPackagesSettingsData } from '../mock_data';

describe('maven form', () => {
  let wrapper;

  const { mavenExternalRegistryUrl, mavenExternalRegistryUsername } =
    dependencyProxyPackagesSettingsData;

  const defaultProps = {
    value: {
      mavenExternalRegistryUrl,
      mavenExternalRegistryUsername,
      mavenExternalRegistryPassword: '',
    },
  };

  const findHeader = () =>
    wrapper.findByRole('heading', { level: 2, name: 'Configure external Maven registry' });

  const findURLFieldDescription = () => wrapper.findByTestId('url-field-description');

  const mountComponent = ({ props = defaultProps } = {}) => {
    wrapper = shallowMountExtended(MavenForm, {
      propsData: { ...props },
      stubs: {
        GlFormGroup,
        GlSprintf,
        CrudComponent,
      },
    });
  };

  it('renders header', () => {
    mountComponent();

    expect(findHeader().exists()).toBe(true);
  });

  describe.each`
    index | field                              | label         | description                             | value                            | trimmed
    ${1}  | ${'mavenExternalRegistryUsername'} | ${'Username'} | ${'Username of the external registry.'} | ${mavenExternalRegistryUsername} | ${true}
    ${2}  | ${'mavenExternalRegistryPassword'} | ${'Password'} | ${'Password of the external registry.'} | ${''}                            | ${false}
  `('$label', ({ index, field, description, label, value, trimmed }) => {
    let formGroup;
    let formInput;

    beforeEach(() => {
      mountComponent();

      formGroup = wrapper.findAllComponents(GlFormGroup).at(index);
      formInput = formGroup.findComponent(GlFormInput);
    });

    it('renders', () => {
      expect(formGroup.attributes()).toMatchObject({
        label,
        description,
      });

      expect(formInput.attributes('value')).toBe(value);
    });

    it('emits trimmed input event', () => {
      formInput.vm.$emit('input', trimmed ? '  new value  ' : 'new value');

      expect(wrapper.emitted('input')).toEqual([[{ ...defaultProps.value, [field]: 'new value' }]]);
    });
  });

  describe('URL', () => {
    let formGroup;
    let formInput;

    beforeEach(() => {
      mountComponent();

      formGroup = wrapper.findAllComponents(GlFormGroup).at(0);
      formInput = formGroup.findComponent(GlFormInput);
    });

    it('renders', () => {
      expect(formGroup.attributes('label')).toBe('URL');
      expect(formInput.attributes('value')).toBe(mavenExternalRegistryUrl);
      expect(findURLFieldDescription().text()).toBe(
        'Base URL of the external registry. Must begin with http or https',
      );
    });

    it('emits trimmed input event', () => {
      formInput.vm.$emit('input', '  new value  ');

      expect(wrapper.emitted('input')).toEqual([
        [{ ...defaultProps.value, mavenExternalRegistryUrl: 'new value' }],
      ]);
    });
  });
});
