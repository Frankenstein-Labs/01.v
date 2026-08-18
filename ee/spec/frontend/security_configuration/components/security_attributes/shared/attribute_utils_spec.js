import { getAttributeCategoryTokens } from 'ee/security_configuration/security_attributes/components/shared/attribute_utils';
import { OPERATORS_IS_NOT_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import AttributeToken from 'ee/security_configuration/security_attributes/components/shared/attribute_token.vue';
import { mockSecurityAttributeCategories } from '../mock_data';

describe('Security attribute utils', () => {
  describe('getAttributeCategoryTokens', () => {
    it('maps securityCategories to filtered search tokens', () => {
      expect(getAttributeCategoryTokens(mockSecurityAttributeCategories)).toStrictEqual([
        {
          type: 'attribute-token-6',
          title: 'Business Impact',
          multiSelect: true,
          unique: true,
          token: AttributeToken,
          categoryId: 6,
          attributeOptions: [
            {
              color: '#e9be74',
              description: 'Supporting administrative functions.',
              id: 10,
              name: 'Business Administrative',
              text: 'Business Administrative',
            },
            {
              color: '#c17d10',
              description: 'Important for key business operations.',
              id: 8,
              name: 'Business Critical',
              text: 'Business Critical',
            },
            {
              color: '#9d6e2b',
              description: 'Standard operational systems.',
              id: 9,
              name: 'Business Operational',
              text: 'Business Operational',
            },
            {
              color: '#ab6100',
              description: 'Essential for core business functions.',
              id: 7,
              name: 'Mission Critical',
              text: 'Mission Critical',
            },
            {
              color: '#f5d9a8',
              description: 'Minimal business impact.',
              id: 11,
              name: 'Non-essential',
              text: 'Non-essential',
            },
          ],
          operators: OPERATORS_IS_NOT_OR,
        },
        {
          type: 'attribute-token-10',
          title: 'Custom',
          multiSelect: true,
          unique: true,
          token: AttributeToken,
          categoryId: 10,
          attributeOptions: [
            {
              color: '#aaa',
              description: 'Example attribute.',
              id: 13,
              name: 'first',
              text: 'first',
            },
          ],
          operators: OPERATORS_IS_NOT_OR,
        },
        {
          type: 'attribute-token-12',
          title: 'Example',
          multiSelect: true,
          unique: true,
          token: AttributeToken,
          categoryId: 12,
          attributeOptions: [
            {
              color: '#fff',
              description: 'Example attribute one.',
              id: 14,
              name: 'One',
              text: 'One',
            },
            {
              color: '#eee',
              description: 'Example attribute two.',
              id: 15,
              name: 'Onee',
              text: 'Onee',
            },
          ],
          operators: OPERATORS_IS_NOT_OR,
        },
      ]);
    });
  });
});
