#!/usr/bin/env groovy
// vim: set et sw=4 ts=4 :

String ipAddress() {
    return sh(returnStdout: true, script: "ip -4 -o addr show eth0 | awk '{ print \$4 }' | awk -F/ '{ print \$1 }'").trim()
}

String domain() {
    return ipAddress() + ".nip.io"
}

String jobBaseName() {
    return env.JOB_BASE_NAME.toLowerCase()
}

void setBuildStatus(String context, String status) {
    def description = null
    switch (status) {
        case 'pending':
            description = 'Tests running'
            break
        case 'success':
            description = 'Tests passed'
            break
        case 'failure':
            description = 'Tests failed'
            break
        default:
            // Also covers 'error' case
            description = 'Unknown error occurred'
            break
    }

    try {
    githubNotify credentialsId: 'creds-github-suse-cf-ci-bot',
                 context: "jenkins/${context}",
                 description: description,
                 status: status.toUpperCase(),
                 targetUrl: env.BUILD_URL
    } catch (IllegalArgumentException e) {
      echo "Can't notify github status (can't infer git data)"
    }
}

void runTest(String testName) {
    sh """
        image=\$(awk '\$1 == "image:" { print \$2 }' output/unzipped/kube/cf*/bosh-task/"${testName}.yaml" | tr -d '"')

        kubectl delete pod --namespace=${jobBaseName()}-${BUILD_NUMBER}-scf "${testName}" || true

        kubectl run \
            --namespace=${jobBaseName()}-${BUILD_NUMBER}-scf \
            --attach \
            --restart=Never \
            --image=\${image} \
            --overrides="\$(ruby bin/kube_overrides.rb "${jobBaseName()}-${BUILD_NUMBER}-scf" "${domain()}" output/unzipped/kube/cf*/bosh-task/"${testName}.yaml")" \
            "${testName}"
    """
}

String distSubDir() {
    try {
        "${CHANGE_ID}"
        return 'prs/'
    } catch (Exception ex) {
        switch (env.BRANCH_NAME) {
            case 'develop':
                return 'develop/'
            case 'master':
                return 'master/'
            default:
                return 'branches/'
        }
    }
}

String distPrefix() {
    try {
        return "PR-${CHANGE_ID}-"
    } catch (Exception ex) {
        if (env.BRANCH_NAME == 'develop' || env.BRANCH_NAME == 'master') {
            return ''
        }
        return java.net.URLEncoder.encode("${BRANCH_NAME}-", "UTF-8")
    }
}

Boolean noOverwrites() {
    switch (env.BRANCH_NAME) {
        case 'master':
            return true
        default:
            return false
    }
}

pipeline {
    agent { label ((["scf"] + (params.AGENT_LABELS ? params.AGENT_LABELS : "").tokenize()).join("&&")) }
    options {
        ansiColor('xterm')
        skipDefaultCheckout() // We do our own checkout so it can be disabled
        timestamps()
        timeout(time: 10, unit: 'HOURS')
        ws('scf')
    }
    parameters {
        booleanParam(
            name: 'SKIP_CHECKOUT',
            defaultValue: false,
            description: 'Skip the checkout step for faster iteration',
        )
        booleanParam(
            name: 'WIPE',
            defaultValue: false,
            description: 'Remove all existing sources and start from scratch',
        )
        booleanParam(
            name: 'CLEAN',
            defaultValue: true,
            description: 'Remove build artifacts that should normally not be reused',
        )
        booleanParam(
            name: 'PUBLISH_DOCKER',
            defaultValue: true,
            description: 'Enable publishing to docker',
        )
        booleanParam(
            name: 'PUBLISH_S3',
            defaultValue: true,
            description: 'Enable publishing to amazon s3',
        )
        booleanParam(
            name: 'TEST_ROTATE',
            defaultValue: true,
            description: 'Trigger secret rotation via helm upgrade',
        )
        booleanParam(
            name: 'TEST_SMOKE',
            defaultValue: true,
            description: 'Run smoke tests',
        )
        booleanParam(
            name: 'TEST_BRAIN',
            defaultValue: true,
            description: 'Run SATS (SCF Acceptance Tests)',
        )
        booleanParam(
            name: 'TEST_CATS',
            defaultValue: true,
            description: 'Run CATS (Cloud Foundry Acceptance Tests)',
        )
        booleanParam(
            name: 'TAR_SOURCES',
            defaultValue: false,
            description: 'Tar sources',
        )
        booleanParam(
            name: 'COMMIT_SOURCES',
            defaultValue: false,
            description: 'Push sources to obs',
        )
        credentials(
            name: 'OBS_CREDENTIALS',
            description: 'Password for build.opensuse.org',
            defaultValue: 'osc-alfred-jenkins',
        )
        credentials(
            name: 'S3_CREDENTIALS',
            description: 'AWS access key / secret key used for publishing',
            defaultValue: 'cred-s3-scf',
        )
        string(
            name: 'S3_REGION',
            description: 'AWS S3 region the target bucket is in',
            defaultValue: 'us-east-1',
        )
        string(
            name: 'S3_BUCKET',
            description: 'AWS S3 bucket to publish to',
            defaultValue: 'cap-release-archives',
        )
        string(
            name: 'S3_PREFIX',
            description: 'AWS S3 prefix to publish to',
            defaultValue: '',
        )
        credentials(
            name: 'DOCKER_CREDENTIALS',
            description: 'Docker credentials used for publishing',
            defaultValue: 'cred-docker-scf',
        )
        string(
            name: 'FISSILE_DOCKER_REGISTRY',
            defaultValue: '',
            description: 'Docker registry to publish to',
        )
        string(
            name: 'FISSILE_DOCKER_ORGANIZATION',
            defaultValue: 'splatform',
            description: 'Docker organization to publish to',
        )
        booleanParam(
            name: 'USE_SLE_BASE',
            defaultValue: false,
            description: 'Generates a build with the SLE stemcell and stack',
        )
        booleanParam(
            name: 'TRIGGER_SLES_BUILD',
            defaultValue: false,
            description: 'Trigger a SLES version of this job',
        )
        string(
            name: 'AGENT_LABELS',
            defaultValue: '',
            description: 'Extra labels for Jenkins slave selection',
        )
    }

    environment {
        FISSILE_DOCKER_REGISTRY = "${params.FISSILE_DOCKER_REGISTRY}"
        FISSILE_DOCKER_ORGANIZATION = "${params.FISSILE_DOCKER_ORGANIZATION}"
        USE_SLE_BASE = "${params.USE_SLE_BASE}"
    }

    stages {
        stage('trigger_sles_build') {
          when {
                expression { return params.TRIGGER_SLES_BUILD }
          }
          steps {
            build job: 'scf-sles-trigger', wait: false, parameters: [string(name: 'JOB_NAME', value: env.JOB_NAME)]
          }
        }

        stage('wipe') {
            when {
                expression { return params.WIPE }
            }
            steps {
                deleteDir()
            }
        }

        stage('clean') {
            when {
                expression { return params.CLEAN }
            }
            steps {
                sh '''
                    #!/bin/bash
                    dump_info() {
                        kubectl get namespace
                        helm list --all
                        docker ps -a
                        docker images
                    }
                    trap dump_info EXIT

                    get_namespaces() {
                        local ns
                        local -A all_ns
                        # Loop until getting namespaces succeeds
                        while test -z "${all_ns[kube-system]:-}" ; do
                            all_ns=[]
                            for ns in $(kubectl get namespace --no-headers --output=custom-columns=:.metadata.name) ; do
                                all_ns[${ns}]=${ns}
                            done
                        done
                        # Only return the namespaces we want
                        for ns in "${all_ns[@]}" ; do
                            if [[ "${ns}" =~ scf|uaa ]] ; then
                                echo "${ns}"
                            fi
                        done
                    }

                    get_namespaces | xargs --no-run-if-empty kubectl delete ns
                    while test -n "$(get_namespaces)"; do
                        sleep 1
                    done

                    # Run `docker rm` commands twice because of internal race condition:
                    # https://github.com/vmware/vic/issues/3196#issuecomment-263295426
                    docker ps --filter=status=exited  --quiet | xargs --no-run-if-empty docker rm || true
                    docker ps --filter=status=exited  --quiet | xargs --no-run-if-empty docker rm
                    docker ps --filter=status=created --quiet | xargs --no-run-if-empty docker rm || true
                    docker ps --filter=status=created --quiet | xargs --no-run-if-empty docker rm
                    # Force delete anything fissile
                    docker ps --filter=name=fissile --all --quiet | xargs --no-run-if-empty docker rm -f || true
                    docker ps --filter=name=fissile --all --quiet | xargs --no-run-if-empty docker rm -f

                    while docker ps -a --format '{{.Names}}' | grep -E -- '-scf_|-uaa_'; do
                        sleep 1
                    done

                    helm list --all --short | grep -E -- '-scf|-uaa' | xargs --no-run-if-empty helm delete --purge

                    docker images --format="{{.Repository}}:{{.Tag}}" | \
                        grep -E '/scf-|/uaa-|^uaa-role-packages:|^scf-role-packages:' | \
                        xargs --no-run-if-empty docker rmi
                '''
            }
        }
        stage('checkout') {
            when {
                expression { return (!params.SKIP_CHECKOUT) || params.WIPE }
            }
            steps {
                sh '''
                    git config --global --replace-all submodule.fetchJobs 0
                '''
                checkout scm
            }
        }
        stage('tools') {
            steps {
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    unset SCF_PACKAGE_COMPILATION_CACHE
                    make ${FISSILE_BINARY}
                '''
            }
        }

        stage('verify_no_overwrite') {
            when {
                expression { return params.PUBLISH_S3 && noOverwrites() }
            }
            steps {
                withAWS(region: params.S3_REGION) {
                    withCredentials([usernamePassword(
                        credentialsId: params.S3_CREDENTIALS,
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                    )]) {
                        script {
                            def expectedVersion = sh(script: '''make show-versions | awk '/^App Version/ { print $4 }' ''', returnStdout: true).trim()
                            if (expectedVersion == null || expectedVersion == '') {
                                error "Failed to find expected version"
                            }
                            echo "Found expected version: ${expectedVersion}"

                            def glob = "*scf-${params.USE_SLE_BASE ? "sle" : "opensuse"}-${expectedVersion}.*.zip"
                            def files = s3FindFiles(bucket: params.S3_BUCKET, path: "${params.S3_PREFIX}${distSubDir()}", glob: glob)
                            if (files.size() > 0) {
                                error "found a file that matches our current version: ${files[0].name}"
                            }
                        }
                    }
                }
            }
        }

        stage('build') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: params.DOCKER_CREDENTIALS,
                    usernameVariable: 'DOCKER_HUB_USERNAME',
                    passwordVariable: 'DOCKER_HUB_PASSWORD',
                )]) {
                    sh '''
                        if [ -n "${FISSILE_DOCKER_REGISTRY}" ]; then
                            docker login -u "${DOCKER_HUB_USERNAME}" -p "${DOCKER_HUB_PASSWORD}" "${FISSILE_DOCKER_REGISTRY}"
                        fi
                    '''
                }
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    unset SCF_PACKAGE_COMPILATION_CACHE

                    make vagrant-prep validate
                '''
            }
        }

        stage('dist') {
            steps {
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    if [ "$USE_SLE_BASE" == "true" ]; then
                        OS="sle"
                    else
                        OS="opensuse"
                    fi
                    unset SCF_PACKAGE_COMPILATION_CACHE
                    rm -f output/scf-${OS}-*.zip
                    make helm bundle-dist
                '''
            }
        }

        stage('deploy') {
            when {
                expression { return params.TEST_SMOKE || params.TEST_BRAIN || params.TEST_CATS }
            }
            steps {
                sh """
                    set -e +x
                    source \${PWD}/.envrc
                    set -x

                    suffix=""
                    if [ "${params.USE_SLE_BASE}" == "true" ]; then
                        OS="sle"
                    else
                        OS="opensuse"
                        suffix="-opensuse"
                    fi

                    kubectl delete storageclass hostpath || /bin/true
                    kubectl create -f - <<< '{"kind":"StorageClass","apiVersion":"storage.k8s.io/v1","metadata":{"name":"hostpath"},"provisioner":"kubernetes.io/host-path"}'

                    # Unzip the bundle
                    rm -rf output/unzipped
                    mkdir -p output/unzipped
                    unzip -e output/scf-\${OS}-*.zip -d output/unzipped

                    # This is more informational -- even if it fails, we want to try running things anyway to see how far we get.
                    ./output/unzipped/kube-ready-state-check.sh || /bin/true

                    helm install output/unzipped/helm/uaa\${suffix} \
                        --name ${jobBaseName()}-${BUILD_NUMBER}-uaa \
                        --namespace ${jobBaseName()}-${BUILD_NUMBER}-uaa \
                        --set env.DOMAIN=${domain()} \
                        --set env.UAA_HOST=uaa.${domain()} \
                        --set env.UAA_PORT=2793 \
                        --set secrets.CLUSTER_ADMIN_PASSWORD=changeme \
                        --set secrets.UAA_ADMIN_CLIENT_SECRET=uaa-admin-client-secret \
                        --set kube.external_ips[0]=${ipAddress()} \
                        --set kube.storage_class.persistent=hostpath

                    . make/include/secrets

                    has_internal_ca() {
                        test "\$(get_secret "${jobBaseName()}-${BUILD_NUMBER}-uaa" "uaa" "INTERNAL_CA_CERT")" != ""
                    }

                    until has_internal_ca ; do
                        sleep 10
                    done

                    UAA_CA_CERT="\$(get_secret "${jobBaseName()}-${BUILD_NUMBER}-uaa" "uaa" "INTERNAL_CA_CERT")"

                    # The extra IP address is to check that the code to set up multiple
                    # addresses for services is working correctly; it isn't used in
                    # actual routing.
                    helm install output/unzipped/helm/cf\${suffix} \
                        --name ${jobBaseName()}-${BUILD_NUMBER}-scf \
                        --namespace ${jobBaseName()}-${BUILD_NUMBER}-scf \
                        --set env.DOMAIN=${domain()} \
                        --set env.UAA_HOST=uaa.${domain()} \
                        --set env.UAA_PORT=2793 \
                        --set secrets.CLUSTER_ADMIN_PASSWORD=changeme \
                        --set secrets.UAA_ADMIN_CLIENT_SECRET=uaa-admin-client-secret \
                        --set secrets.UAA_CA_CERT="\${UAA_CA_CERT}" \
                        --set "kube.external_ips[0]=192.0.2.84" \
                        --set "kube.external_ips[1]=${ipAddress()}" \
                        --set kube.storage_class.persistent=hostpath

                    echo Waiting for all pods to be ready...
                    for ns in "${jobBaseName()}-${BUILD_NUMBER}-uaa" "${jobBaseName()}-${BUILD_NUMBER}-scf" ; do
                        make/wait "\${ns}"
                    done
                    kubectl get pods --all-namespaces
                """
            }
        }

        stage('rotate') {
            when {
                expression { return params.TEST_ROTATE }
            }
            steps {
                setBuildStatus('secret rotation', 'pending')
                runTest('smoke-tests')
                sh """
                    set -e +x
                    source \${PWD}/.envrc
                    set -x

                    suffix=""
                    if [ "${params.USE_SLE_BASE}" == "false" ]; then
                        suffix="-opensuse"
                    fi

                    . make/include/secrets

                    # Run helm upgrade with a new kube setting to test that secrets are regenerated

                    helm upgrade "${jobBaseName()}-${BUILD_NUMBER}-uaa" output/unzipped/helm/uaa\${suffix} \
                        --namespace ${jobBaseName()}-${BUILD_NUMBER}-uaa \
                        --set env.DOMAIN=${domain()} \
                        --set env.UAA_HOST=uaa.${domain()} \
                        --set env.UAA_PORT=2793 \
                        --set secrets.CLUSTER_ADMIN_PASSWORD=changeme \
                        --set secrets.UAA_ADMIN_CLIENT_SECRET=uaa-admin-client-secret \
                        --set kube.external_ips[0]=${ipAddress()} \
                        --set kube.storage_class.persistent=hostpath \
                        --set kube.secrets_generation_counter=2

                    # Ensure old pods have time to terminate
                    sleep 60
                    echo Waiting for all pods to be ready after the 'upgrade'...
                    set +o xtrace
                    for ns in "${jobBaseName()}-${BUILD_NUMBER}-uaa" ; do
                        # Note that we only check UAA here; SCF is probably going to fall over because the secrets changed
                        make/wait "\${ns}"
                    done
                    set -o xtrace

                    UAA_CA_CERT="\$(get_secret "${jobBaseName()}-${BUILD_NUMBER}-uaa" "uaa" "INTERNAL_CA_CERT")"

                    # The extra IP address is to check that the code to set up multiple
                    # addresses for services is working correctly; it isn't used in
                    # actual routing.
                    helm upgrade "${jobBaseName()}-${BUILD_NUMBER}-scf" output/unzipped/helm/cf\${suffix} \
                        --namespace ${jobBaseName()}-${BUILD_NUMBER}-scf \
                        --set env.DOMAIN=${domain()} \
                        --set env.UAA_HOST=uaa.${domain()} \
                        --set env.UAA_PORT=2793 \
                        --set secrets.CLUSTER_ADMIN_PASSWORD=changeme \
                        --set secrets.UAA_ADMIN_CLIENT_SECRET=uaa-admin-client-secret \
                        --set secrets.UAA_CA_CERT="\${UAA_CA_CERT}" \
                        --set "kube.external_ips[0]=192.0.2.84" \
                        --set "kube.external_ips[1]=${ipAddress()}" \
                        --set kube.storage_class.persistent=hostpath \
                        --set kube.secrets_generation_counter=2

                    # Ensure old pods have time to terminate
                    sleep 60

                    echo Waiting for all pods to be ready after the 'upgrade'...
                    set +o xtrace
                    for ns in "${jobBaseName()}-${BUILD_NUMBER}-uaa" "${jobBaseName()}-${BUILD_NUMBER}-scf" ; do
                        make/wait "\${ns}"
                    done
                    kubectl get pods --all-namespaces
                """

            }
            post {
                success {
                    setBuildStatus('secret rotation', 'success')
                }
                failure {
                    setBuildStatus('secret rotation', 'failure')
                }
            }
        }

        stage('smoke') {
            when {
                expression { return params.TEST_SMOKE }
            }
            steps {
                setBuildStatus('smoke', 'pending')
                runTest('smoke-tests')
            }
            post {
                success {
                    setBuildStatus('smoke', 'success')
                }
                failure {
                    setBuildStatus('smoke', 'failure')
                }
            }
        }

        stage('brain') {
            when {
                expression { return params.TEST_BRAIN }
            }
            steps {
                setBuildStatus('brain', 'pending')
                runTest('acceptance-tests-brain')
            }
            post {
                success {
                    setBuildStatus('brain', 'success')
                }
                failure {
                    setBuildStatus('brain', 'failure')
                }
            }
        }

        stage('cats') {
            when {
                expression { return params.TEST_CATS }
            }
            steps {
                setBuildStatus('cats', 'pending')
                runTest('acceptance-tests')
            }
            post {
                success {
                    setBuildStatus('cats', 'success')
                }
                failure {
                    setBuildStatus('cats', 'failure')
                }
            }
        }

        stage('tar_sources') {
          when {
                expression { return params.TAR_SOURCES }
          }
          steps {
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    make tar-sources
                '''
          }
        }

        stage('commit_sources') {
          when {
                expression { return params.COMMIT_SOURCES }
          }
          steps {
                withCredentials([usernamePassword(
                    credentialsId: params.OBS_CREDENTIALS,
                    usernameVariable: 'OBS_CREDENTIALS_USERNAME',
                    passwordVariable: 'OBS_CREDENTIALS_PASSWORD',
                )]) {
                sh '''
                  set -e +x
                  source ${PWD}/.envrc
                  echo -e "[general]
apiurl = https://api.opensuse.org
[https://api.opensuse.org]
user = ${OBS_CREDENTIALS_USERNAME}
pass = ${OBS_CREDENTIALS_PASSWORD}
" > ~/.oscrc
                  make osc-commit-sources
                  rm ~/.oscrc
                '''
                }
          }
        }

        stage('publish_docker') {
            when {
                expression { return params.PUBLISH_DOCKER }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: params.DOCKER_CREDENTIALS,
                    usernameVariable: 'DOCKER_HUB_USERNAME',
                    passwordVariable: 'DOCKER_HUB_PASSWORD',
                )]) {
                    sh 'docker login -u "${DOCKER_HUB_USERNAME}" -p "${DOCKER_HUB_PASSWORD}" "${FISSILE_DOCKER_REGISTRY}" '
                }
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    unset SCF_PACKAGE_COMPILATION_CACHE
                    make publish
                '''
            }
        }

        stage('publish_s3') {
            when {
                expression { return params.PUBLISH_S3 }
            }
            steps {
                withAWS(region: params.S3_REGION) {
                    withCredentials([usernamePassword(
                        credentialsId: params.S3_CREDENTIALS,
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                    )]) {
                        script {
                            def files = findFiles(glob: "output/scf-${params.USE_SLE_BASE ? "sle" : "opensuse"}-*.zip")
                            def subdir = "${params.S3_PREFIX}${distSubDir()}"
                            def prefix = distPrefix()

                            for ( int i = 0 ; i < files.size() ; i ++ ) {
                                s3Upload(
                                    file: files[i].path,
                                    bucket: "${params.S3_BUCKET}",
                                    path: "${subdir}${prefix}${files[i].name}",
                                )
                            }

                            // Escape twice or the url will be unescaped when passed to the Jenkins form. It will then not work in the script.
                            def encodedFileName = java.net.URLEncoder.encode(files[0].name, "UTF-8")
                            def encodedCapBundleUri = java.net.URLEncoder.encode("https://s3.amazonaws.com/${params.S3_BUCKET}/${params.S3_PREFIX}${distSubDir()}${distPrefix()}${encodedFileName}", "UTF-8")
                            def encodedBuildUri = java.net.URLEncoder.encode(BUILD_URL, "UTF-8")

                            echo "Create a cap release using this link: https://cap-release-tool.suse.de/?release_archive_url=${encodedCapBundleUri}&SOURCE_BUILD=${encodedBuildUri}"
                            echo "Open a Pull Request for the helm repository using this link: http://jenkins-new.howdoi.website/job/helm-charts/parambuild?CAP_BUNDLE=${encodedCapBundleUri}&SOURCE_BUILD=${encodedBuildUri}"
                        }
                    }
                }
            }
        }
    }
}
