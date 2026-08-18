import { gql } from '@apollo/client/core';

// Query.geoNode to be renamed to Query.geoSite => https://gitlab.com/gitlab-org/gitlab/-/issues/396739
export default (graphQlClassID, graphQlFieldName, verificationEnabled) => {
  return gql`
    query($ids: [${graphQlClassID}!]) {
      geoNode {
        ${graphQlFieldName}(ids: $ids) {
          nodes {
            id
            checksumMismatch
            createdAt
            dataManagementDetailsPath @gl_introduced(version: "18.9.0")
            lastSyncFailure
            lastSyncedAt
            missingOnPrimary
            modelRecordId
            retryAt
            retryCount
            state
            verificationChecksum @include (if: ${verificationEnabled})
            verificationChecksumMismatched @include (if: ${verificationEnabled})
            verificationFailure @include (if: ${verificationEnabled})
            verificationRetryAt @include (if: ${verificationEnabled})
            verificationRetryCount @include (if: ${verificationEnabled})
            verificationStartedAt @include (if: ${verificationEnabled})
            verificationState @include (if: ${verificationEnabled})
            verifiedAt @include (if: ${verificationEnabled})
          }
        }
      }
    }
  `;
};
