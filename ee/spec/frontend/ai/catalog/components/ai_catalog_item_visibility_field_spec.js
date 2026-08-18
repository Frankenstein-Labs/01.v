import { GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import {
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_BADGE_VARIANT,
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
} from 'ee/ai/catalog/constants';

describe('AiCatalogItemVisibilityField', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemVisibilityField, {
      propsData: {
        public: false,
        visibility: VISIBILITY_LEVEL_PUBLIC,
        descriptionTexts: AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
        ...props,
      },
      provide,
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);

  describe('when aiCatalogInternalVisibility is enabled', () => {
    it.each`
      visibility                     | expectedLabel   | expectedIcon                                         | expectedVariant
      ${VISIBILITY_LEVEL_PUBLIC}     | ${'Public'}     | ${VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC]}     | ${VISIBILITY_LEVEL_BADGE_VARIANT[VISIBILITY_LEVEL_PUBLIC]}
      ${VISIBILITY_LEVEL_RESTRICTED} | ${'Restricted'} | ${VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_RESTRICTED]} | ${VISIBILITY_LEVEL_BADGE_VARIANT[VISIBILITY_LEVEL_RESTRICTED]}
      ${VISIBILITY_LEVEL_PRIVATE}    | ${'Private'}    | ${VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE]}    | ${VISIBILITY_LEVEL_BADGE_VARIANT[VISIBILITY_LEVEL_PRIVATE]}
    `(
      'renders $expectedLabel badge when visibility is $visibility',
      ({ visibility, expectedLabel, expectedIcon, expectedVariant }) => {
        createComponent({
          props: { visibility },
          provide: { glFeatures: { aiCatalogInternalVisibility: true } },
        });

        expect(findBadge().text()).toBe(expectedLabel);
        expect(findBadge().props('icon')).toBe(expectedIcon);
        expect(findBadge().props('variant')).toBe(expectedVariant);
      },
    );

    it('renders the correct description for each visibility level', () => {
      createComponent({
        props: { visibility: VISIBILITY_LEVEL_RESTRICTED },
        provide: { glFeatures: { aiCatalogInternalVisibility: true } },
      });

      expect(wrapper.text()).toContain(
        AGENT_VISIBILITY_LEVEL_DESCRIPTIONS[VISIBILITY_LEVEL_RESTRICTED],
      );
    });
  });

  describe('when aiCatalogInternalVisibility is disabled', () => {
    it.each`
      isPublic | expectedLabel | expectedIcon
      ${true}  | ${'Public'}   | ${VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC]}
      ${false} | ${'Private'}  | ${VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE]}
    `(
      'derives $expectedLabel badge from the public boolean when visibility is $visibility',
      ({ isPublic, expectedLabel, expectedIcon }) => {
        createComponent({
          props: {
            public: isPublic,
            // Pass a mismatching visibility to prove the public flag drives the badge.
            visibility: VISIBILITY_LEVEL_RESTRICTED,
          },
        });

        expect(findBadge().text()).toBe(expectedLabel);
        expect(findBadge().props('icon')).toBe(expectedIcon);
      },
    );
  });
});
