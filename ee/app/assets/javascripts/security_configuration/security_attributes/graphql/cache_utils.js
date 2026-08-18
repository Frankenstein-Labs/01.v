/* eslint-disable no-underscore-dangle */
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import {
  BULK_EDIT_ADD,
  BULK_EDIT_REMOVE,
  BULK_EDIT_REPLACE,
} from 'ee/security_configuration/components/security_attributes/constants';

const attributeIdToRef = (id) => `SecurityAttribute:${id}`;

const canAddAttributeToProject = (attributeRef, cachedProjectAttributeNodes, categories) => {
  const attributeCategory = categories.find((category) =>
    category.securityAttributes.some(
      (categoryAttribute) => attributeRef === attributeIdToRef(categoryAttribute.id),
    ),
  );

  // return true if the category allows multiple selection
  if (attributeCategory.multipleSelection) {
    return true;
  }

  // return false if any attribute the project already has belongs to the same category
  if (
    cachedProjectAttributeNodes.some((projectAttributeNode) =>
      attributeCategory.securityAttributes.some(
        (categoryAttribute) =>
          projectAttributeNode.__ref === attributeIdToRef(categoryAttribute.id),
      ),
    )
  ) {
    return false;
  }

  // otherwise this is the only attribute the project has from this category
  return true;
};

const mergeNodes = (existingNodes, nodesToAdd, categories) => [
  ...existingNodes,
  ...nodesToAdd.filter(
    (nodeToAdd) =>
      !existingNodes.some((existingNode) => existingNode.__ref === nodeToAdd.__ref) &&
      canAddAttributeToProject(nodeToAdd.__ref, existingNodes, categories),
  ),
];
const removeNodes = (existingNodes, nodesToRemove) => [
  ...existingNodes.filter(
    (cachedAttributeNode) =>
      !nodesToRemove.some((nodeToRemove) => cachedAttributeNode.__ref === nodeToRemove.__ref),
  ),
];

export const updateSecurityAttributes =
  (attributes, mode, categories) => (cachedProjectAttributes) => {
    let nodes;

    if (mode === BULK_EDIT_ADD) {
      nodes = mergeNodes(cachedProjectAttributes.nodes, attributes, categories);
    }
    if (mode === BULK_EDIT_REMOVE) {
      nodes = removeNodes(cachedProjectAttributes.nodes, attributes);
    }
    if (mode === BULK_EDIT_REPLACE) {
      nodes = attributes;
    }

    return {
      ...cachedProjectAttributes,
      nodes,
    };
  };

const updateItem = ({ cache, itemId, attributes, mode, categories }) => {
  const item = cache.identify({ __typename: TYPENAME_PROJECT, id: itemId });
  if (!item) return;

  const attributeRefs = attributes.map((id) => ({ __ref: attributeIdToRef(id) }));

  cache.modify({
    id: item,
    fields: {
      securityAttributes: updateSecurityAttributes(attributeRefs, mode, categories),
    },
    broadcast: false,
  });
};

export const updateSecurityAttributesCache =
  ({ items, attributes, mode }, categories) =>
  (cache, { data: { bulkUpdateSecurityAttributes } }) => {
    if (bulkUpdateSecurityAttributes.errors.length) {
      items.forEach((id) => cache.evict(id));
      return;
    }
    items.forEach((itemId) => updateItem({ cache, itemId, attributes, mode, categories }));
  };
