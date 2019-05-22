# Enabling authentication on a new cluster

**Steps**

1. Run the following docker command to generate the root/admin certs to a directory of your choice
`docker run -d -v "$(pwd)"/out:/tools/out quay.io/sysdig/elasticsearch:1.0.1-es-certs`
2. Generate the required kubernetes secret file 
`kubectl -n <my-namespace> create secret generic ca-certs --from-file=out`
3. Generate the password secrets for the admin/readonly searchguard roles
`kubectl -n <my-namespace> create secret generic sg-admin-secret --from-literal=password='<admin-password-here>'`
`kubectl -n <my-namespace> create secret generic sg-readonly-secret --from-literal=password='<readonly-password-here>'`
4. Uncomment all the required environment variables/volumes that will be needed for setting up AWS Security Group 
5. Make sure that `elasticsearch.searchguard.enabled` is set to "true" in `sysdigcloud/config.yaml` and set `elasticsearch.user` to the searchguard role that the elasticsearch cluster will be using
6. Create the elasticsearch cluster `kubectl -n <my-namespace> create -f elasticsearch-statefulset.yaml`

# Search Guard Configuration Files

The current configuration contains only the 2 roles mentioned above. If you would like to add more roles/personalize the configuration further, you can edit the files under the `sgconfig` directory before creating the secret. 

For new roles/users make sure to follow the format that is shown for the existing two users (using environment variables):
```
user:
  hash: ${USR_PWD_HASH_ENV_VAR}
  #password is: ${USR_PASSWORD}
  roles:
  - sg_role
  - ...
```
For each user that you create you should also create a secret for the password in the namespace like admin/readonly above
`kubectl -n <my-namespace> create secret generic sg-<my-role>-secret --from-literal=password='<role-password-here>'`

You will then need to add a block in `elasticsearch-statefulset.yaml` to pass the secret in as an environment variable like the admin/readonly vars

```
- name: MYROLE_PASSWORD
    valueFrom:
    secretKeyRef:
        name: sg-<my-role>-secret
        key: password
```

If you would like to use this role/password you need to make sure to set `elasticsearch.user` to your role name in `config.yaml` and also set the `secretKeyRef` for the `SG_PASSWORD` environment variable to be the name of your new password secret. By default `SG_PASSWORD` is set to the admin pass and `elasticsearch.user` is admin

Once you are satisfied with the configuration, run the following command:
`kubectl -n <my-namespace> create secret generic sg-config-files --from-file=sgconfig`

# Search Guard Roles

There are currently only 2 roles that SG has set up:
- **admin**: Has access to everything in the cluster and all indices
- **readonly**: Can only read indices and access monitoring endpoints for the cluster (Ex. Health)

# Enabling authentication on an existing cluster

The steps for enabling on an existing cluster are almost the same as for enabling on a new cluster.

Follow steps 1-5 from `Enabling authentication on a new cluster` and then you will need to `apply` your changes for both the config and statefulset files.
`kubectl -n <my-namespace> apply -f config.yaml`
`kubectl -n <my-namespace> apply -f elasticsearch-statefulset.yaml`

After the changes have been applied you can restart the elasticsearch cluster by deleting the current pods to trigger a restart/update
`kubectl -n <my-namespace> delete pod -l component=elasticsearch`
