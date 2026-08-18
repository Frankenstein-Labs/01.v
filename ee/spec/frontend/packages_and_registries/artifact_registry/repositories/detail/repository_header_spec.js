import { GlBadge, GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import FormatLogo from 'ee/packages_and_registries/artifact_registry/repositories/components/format_logo.vue';
import RepositoryActions from 'ee/packages_and_registries/artifact_registry/repositories/detail/repository_actions.vue';
import RepositoryHeader from 'ee/packages_and_registries/artifact_registry/repositories/detail/repository_header.vue';
import { createRouter } from 'ee/packages_and_registries/artifact_registry/router';
import { BASE_PATH, mockRepository } from '../../mock_data';

describe('ArtifactRegistryRepositoryHeader', () => {
  let wrapper;

  const findName = () => wrapper.findByTestId('repository-name');
  const findFormatLogo = () => wrapper.findComponent(FormatLogo);
  const findFormatName = () => wrapper.findByTestId('repository-format-name');
  const findVisibilityButton = () => wrapper.findComponentByTestId('repository-visibility');
  const findVisibilityIcon = () => findVisibilityButton().findComponent(GlIcon);
  const findKindBadge = () => wrapper.findComponent(GlBadge);
  const findDescription = () => wrapper.findByTestId('repository-description');
  const findActionArea = () => wrapper.findByTestId('page-heading-actions');
  const findActions = () => findActionArea().findComponent(RepositoryActions);
  const findEditButton = () => wrapper.findByTestId('edit-repository');

  const createComponent = (overrides = {}) => {
    wrapper = mountExtended(RepositoryHeader, {
      propsData: { repository: { ...mockRepository, ...overrides } },
      // The Edit button is a router link, which needs a router to resolve its target.
      router: createRouter(BASE_PATH),
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      // The actions carry their own router, Apollo, and injections. This spec covers
      // where the header puts them, not what they do.
      stubs: { RepositoryActions: true },
    });
  };

  it('renders the repository name, which names the page', () => {
    createComponent({ name: 'payment-core' });

    expect(findName().text()).toBe('payment-core');
  });

  describe('the format icon', () => {
    describe.each([
      ['MAVEN', 'Maven'],
      ['NPM', 'npm'],
      ['DOCKER', 'Docker'],
      ['OCI', 'OCI'],
    ])('for a %s repository', (format, label) => {
      beforeEach(() => {
        createComponent({ format });
      });

      it('renders the logo of that format', () => {
        expect(findFormatLogo().props('format')).toBe(format);
      });

      // The logo is decorative, so without this the format goes unannounced: no other
      // text in the header states it.
      it(`names it ${label} for assistive technology`, () => {
        expect(findFormatName().text()).toBe(label);
        expect(findFormatName().classes()).toContain('gl-sr-only');
      });
    });

    it('renders the logo at the heading size, larger than the one the list reads at', () => {
      createComponent();

      expect(findFormatLogo().props('size')).toBe(48);
    });
  });

  // Closed beta supports private only: both public and internal grant read without a
  // role assignment, which breaks closed-by-default, so ADR-021 defers them to GA.
  describe('for a PRIVATE repository', () => {
    beforeEach(() => {
      createComponent({ visibility: 'PRIVATE' });
    });

    it('renders the lock visibility icon', () => {
      expect(findVisibilityIcon().props('name')).toBe('lock');
    });

    it('names it Private for assistive technology', () => {
      expect(findVisibilityButton().attributes('aria-label')).toBe('Private');
    });

    it('reaches keyboard users, which a bare icon does not', () => {
      expect(findVisibilityButton().element.tagName).toBe('BUTTON');
    });

    it('labels it Private on hover and focus', () => {
      expect(getBinding(findVisibilityButton().element, 'gl-tooltip')).toBeDefined();
      expect(findVisibilityButton().attributes('title')).toBe('Private');
    });
  });

  it('renders the kind as a badge, always Hosted on this page', () => {
    createComponent({ kind: 'HOSTED' });

    expect(findKindBadge().text()).toBe('Hosted');
  });

  it('renders the actions in the heading action area, not loose in the header', () => {
    createComponent();

    expect(findActions().exists()).toBe(true);
    expect(findActions().props('repository')).toStrictEqual(mockRepository);
  });

  describe('the edit button', () => {
    beforeEach(() => {
      createComponent({ name: 'payment-core' });
    });

    // The button is the primary write affordance, so it sits outside the kebab, and
    // ahead of it: the actions the kebab holds are the less common ones.
    it('renders in the heading action area, before the kebab', () => {
      expect(findActionArea().exists()).toBe(true);
      expect(findEditButton().exists()).toBe(true);
      expect(findActionArea().element.firstElementChild).toBe(findEditButton().element);
    });

    it('links to the edit view for the repository the page names', () => {
      expect(findEditButton().attributes('href')).toBe(`${BASE_PATH}/payment-core/edit`);
    });

    // The heading beside it already names the repository.
    it('is labelled Edit', () => {
      expect(findEditButton().text()).toBe('Edit');
    });
  });

  describe('the description', () => {
    it('renders the repository description', () => {
      createComponent({ description: 'Artifacts for the payments monorepo' });

      expect(findDescription().text()).toBe('Artifacts for the payments monorepo');
    });

    it('is left out when the repository has none, and the rest of the header still renders', () => {
      createComponent({ description: null });

      expect(findDescription().exists()).toBe(false);
      expect(findName().exists()).toBe(true);
    });
  });
});
