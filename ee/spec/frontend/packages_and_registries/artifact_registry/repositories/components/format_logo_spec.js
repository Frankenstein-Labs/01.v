import { GlAvatar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FormatLogo from 'ee/packages_and_registries/artifact_registry/repositories/components/format_logo.vue';

describe('ArtifactRegistryFormatLogo', () => {
  let wrapper;

  const findImage = () => wrapper.find('img');
  const findAvatar = () => wrapper.findComponent(GlAvatar);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(FormatLogo, {
      propsData: {
        format: 'MAVEN',
        ...props,
      },
    });
  };

  describe.each([
    ['MAVEN', 'maven'],
    ['NPM', 'npm'],
    ['DOCKER', 'docker'],
  ])('for the %s format', (format, logo) => {
    beforeEach(() => {
      createComponent({ format });
    });

    it(`renders the ${logo} logo`, () => {
      // Read the DOM property, not the attribute: Vue 3 sets img.src as a property and
      // renders no src attribute, while Vue 2 renders both.
      expect(findImage().element.src).toContain(`${logo}.svg`);
    });

    it('renders no letter avatar, because the format has a logo of its own', () => {
      expect(findAvatar().exists()).toBe(false);
    });
  });

  // OCI has no logo of its own until the trademark is cleared, and borrowing another
  // format's logo would name the wrong thing.
  describe('for a format with no logo', () => {
    beforeEach(() => {
      createComponent({ format: 'OCI' });
    });

    it('falls back to the letter avatar of its label', () => {
      expect(findAvatar().props('entityName')).toBe('OCI');
    });

    it('renders the avatar as a square, matching the logos it stands in for', () => {
      expect(findAvatar().props('shape')).toBe('rect');
    });

    it('renders no image', () => {
      expect(findImage().exists()).toBe(false);
    });
  });

  describe('the size', () => {
    it('sizes the logo as a square, so every format lines up with the others', () => {
      createComponent({ size: 32 });

      expect(findImage().attributes()).toMatchObject({ width: '32', height: '32' });
    });

    it('sizes the fallback avatar to match', () => {
      createComponent({ format: 'OCI', size: 32 });

      expect(findAvatar().props('size')).toBe(32);
    });
  });

  // The fallback avatar renders itself `aria-hidden` and takes no alternative text, so a
  // logo that named its format would be announced for some formats and not others. The
  // caller names the format instead.
  it('leaves the logo decorative', () => {
    createComponent();

    expect(findImage().attributes('alt')).toBe('');
  });
});
