import {
  BULK_EDIT_ADD,
  BULK_EDIT_REMOVE,
  BULK_EDIT_REPLACE,
} from 'ee/security_configuration/components/security_attributes/constants';
import {
  updateSecurityAttributes,
  updateSecurityAttributesCache,
} from 'ee/security_configuration/security_attributes/graphql/cache_utils';

describe('cache utils', () => {
  const categories = [
    {
      id: 'gid://gitlab/Security::Category/1',
      multipleSelection: false,
      securityAttributes: [
        {
          id: 'gid://gitlab/Security::Attribute/1',
        },
        {
          id: 'gid://gitlab/Security::Attribute/4',
        },
      ],
    },
    {
      id: 'gid://gitlab/Security::Category/2',
      multipleSelection: true,
      securityAttributes: [
        {
          id: 'gid://gitlab/Security::Attribute/2',
        },
        {
          id: 'gid://gitlab/Security::Attribute/5',
        },
        {
          id: 'gid://gitlab/Security::Attribute/6',
        },
      ],
    },
  ];
  const cachedProjectAttributes = {
    nodes: [
      { __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/1' },
      { __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/2' },
      { __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/3' },
    ],
  };

  describe('updateSecurityAttributes', () => {
    it.each`
      description                                                               | mode                 | attributes                                                                                                                                | expectedLength
      ${'adds an attribute for a multiple selection category'}                  | ${BULK_EDIT_ADD}     | ${[{ __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/5' }]}                                                                    | ${4}
      ${'adds many attributes for a multiple selection category'}               | ${BULK_EDIT_ADD}     | ${[{ __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/5' }, { __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/6' }]} | ${5}
      ${'does not add if project has attribute from single selection category'} | ${BULK_EDIT_ADD}     | ${[{ __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/4' }]}                                                                    | ${3}
      ${'removes an attribute'}                                                 | ${BULK_EDIT_REMOVE}  | ${[{ __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/3' }]}                                                                    | ${2}
      ${'removes many attributes'}                                              | ${BULK_EDIT_REMOVE}  | ${[{ __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/2' }, { __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/3' }]} | ${1}
      ${'replaces attributes'}                                                  | ${BULK_EDIT_REPLACE} | ${[{ __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/4' }, { __ref: 'SecurityAttribute:gid://gitlab/Security::Attribute/5' }]} | ${2}
    `('$description', ({ mode, attributes, expectedLength }) => {
      expect(
        updateSecurityAttributes(attributes, mode, categories)(cachedProjectAttributes).nodes,
      ).toHaveLength(expectedLength);
    });
  });

  describe('updateSecurityAttributesCache', () => {
    const cache = {
      identify: jest.fn().mockResolvedValue({ __ref: 'the project' }),
      modify: jest.fn(),
    };
    const responseWithNoErrors = { data: { bulkUpdateSecurityAttributes: { errors: [] } } };

    it('calls cache.modify for each item', () => {
      const items = [{ id: 'gid://gitlab/Project/1' }, { id: 'gid://gitlab/Project/2' }];
      const attributes = [
        'gid://gitlab/Security::Attribute/1',
        'gid://gitlab/Security::Attribute/2',
      ];
      const mode = BULK_EDIT_ADD;

      updateSecurityAttributesCache({ items, attributes, mode }, categories)(
        cache,
        responseWithNoErrors,
      );

      expect(cache.modify).toHaveBeenCalledTimes(items.length);
    });
  });
});
