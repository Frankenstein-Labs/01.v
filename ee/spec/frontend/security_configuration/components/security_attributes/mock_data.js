import {
  CATEGORY_EDITABLE,
  CATEGORY_PARTIALLY_EDITABLE,
  CATEGORY_LOCKED,
} from 'ee/security_configuration/components/security_attributes/constants';

export const mockSecurityAttributesWithCategories = [
  {
    id: 'gid://gitlab/Security::Attribute/14',
    securityCategory: {
      id: 'gid://gitlab/Security::Category/12',
      name: 'new',
      __typename: 'SecurityCategory',
    },
    name: 'one',
    description: 'one',
    color: '#eee',
    __typename: 'SecurityAttribute',
  },
  {
    id: 'gid://gitlab/Security::Attribute/13',
    securityCategory: {
      id: 'gid://gitlab/Security::Category/11',
      name: 'hello 2',
      __typename: 'SecurityCategory',
    },
    name: 'second',
    description: 'test2',
    color: '#fff',
    __typename: 'SecurityAttribute',
  },
  {
    id: 'gid://gitlab/Security::Attribute/12',
    securityCategory: {
      id: 'gid://gitlab/Security::Category/11',
      name: 'hello 2',
      __typename: 'SecurityCategory',
    },
    name: 'third',
    description: 'test3',
    color: '#000',
    __typename: 'SecurityAttribute',
  },
  {
    id: 'gid://gitlab/Security::Attribute/11',
    securityCategory: {
      id: 'gid://gitlab/Security::Category/11',
      name: 'hello 2',
      __typename: 'SecurityCategory',
    },
    name: 'fourth',
    description: 'test4',
    color: '#444',
    __typename: 'SecurityAttribute',
  },
  {
    id: 'gid://gitlab/Security::Attribute/10',
    securityCategory: {
      id: 'gid://gitlab/Security::Category/11',
      name: 'hello 2',
      __typename: 'SecurityCategory',
    },
    name: 'fifth',
    description: 'test4',
    color: '#888',
    __typename: 'SecurityAttribute',
  },
];

export const mockSecurityAttributeCategories = [
  {
    id: 6,
    name: 'Business Impact',
    description: 'Classify projects by their importance to business operations.',
    multipleSelection: false,
    editableState: CATEGORY_PARTIALLY_EDITABLE,
    templateType: 'BUSINESS_IMPACT',
    securityAttributes: [
      {
        id: 10,
        name: 'Business Administrative',
        description: 'Supporting administrative functions.',
        color: '#e9be74',
      },
      {
        id: 8,
        name: 'Business Critical',
        description: 'Important for key business operations.',
        color: '#c17d10',
      },
      {
        id: 9,
        name: 'Business Operational',
        description: 'Standard operational systems.',
        color: '#9d6e2b',
      },
      {
        id: 7,
        name: 'Mission Critical',
        description: 'Essential for core business functions.',
        color: '#ab6100',
      },
      {
        id: 11,
        name: 'Non-essential',
        description: 'Minimal business impact.',
        color: '#f5d9a8',
      },
    ],
  },
  {
    id: 10,
    name: 'Custom',
    description: 'Custom category for experimental tagging.',
    multipleSelection: true,
    editableState: CATEGORY_LOCKED,
    templateType: null,
    securityAttributes: [
      {
        id: 13,
        name: 'first',
        description: 'Example attribute.',
        color: '#aaa',
      },
    ],
  },
  {
    id: 12,
    name: 'Example',
    description: 'Example category used for testing.',
    multipleSelection: true,
    editableState: CATEGORY_EDITABLE,
    templateType: null,
    securityAttributes: [
      {
        id: 14,
        name: 'One',
        description: 'Example attribute one.',
        color: '#fff',
      },
      {
        id: 15,
        name: 'Onee',
        description: 'Example attribute two.',
        color: '#eee',
      },
    ],
  },
];

export const mockFailedCategoryCreateResponse = {
  data: {
    securityCategoryCreate: {
      securityCategory: null,
      errors: ['Namespace cannot have more than 20 categories'],
      __typename: 'SecurityCategoryCreatePayload',
    },
  },
};

export const mockFailedAttributeCreateResponse = {
  data: {
    securityAttributeCreate: {
      securityAttributes: null,
      errors: ['Category cannot have more than 5 attributes.'],
      __typename: 'SecurityAttributeCreatePayload',
    },
  },
};

export const mockFailedAttributeUpdateResponse = {
  data: {
    securityAttributeUpdate: {
      securityAttribute: null,
      errors: ['Name has already been taken'],
      __typename: 'SecurityAttributeUpdatePayload',
    },
  },
};

export const expectedAttributes = [
  {
    id: 3,
    categoryId: 11,
    name: 'Capital Commit',
    description:
      'An enterprise lending solution that manages the complete lifecycle of commercial loans from application to disbursement.',
    color: '#EC6337',
    projectCount: 2,
    category: {
      id: 11,
      name: 'Application',
      description: 'Categorize projects by application type and technology stack.',
      multipleSelection: true,
      canEditCategory: false,
      canEditsecurityAttributes: true,
      attributeCount: 8,
    },
  },
  {
    id: 4,
    categoryId: 11,
    name: 'Deposit Source',
    description:
      'A savings account management system that handles interest calculations, automatic transfers, and customer-facing deposit operations.',
    color: '#613CB1',
    projectCount: 59,
    category: {
      id: 11,
      name: 'Application',
      description: 'Categorize projects by application type and technology stack.',
      multipleSelection: true,
      canEditCategory: false,
      canEditsecurityAttributes: true,
      attributeCount: 8,
    },
  },
  {
    id: 11,
    categoryId: 12,
    name: 'Business Operational',
    description: 'Standard operational systems',
    color: '#CF9846',
    projectCount: 2,
    category: {
      id: 12,
      name: 'Business Impact',
      description: 'Classify projects by their importance to business operations.',
      multipleSelection: false,
      canEditCategory: false,
      canEditsecurityAttributes: false,
      attributeCount: 5,
    },
  },
  {
    id: 15,
    categoryId: 15,
    name: 'Singapore::Singapore',
    description: 'Asia-Pacific regional office covering Southeast Asian operations.',
    color: '#D3875B',
    projectCount: 31,
    category: {
      id: 15,
      name: 'Location',
      description: 'Track system hosting locations and geographic deployment.',
      multipleSelection: false,
      canEditCategory: true,
      canEditsecurityAttributes: true,
      attributeCount: 7,
    },
  },
];
