#!/bin/bash
images="rancher-images.tar.gz"
list="rancher-images.txt"
windows_image_list=""
windows_versions="1903"
usage () {
    echo "USAGE: $0 [--images rancher-images.tar.gz] --registry my.registry.com:5000"
    echo "  [-l|--image-list path] text file with list of images; one image per line."
    echo "  [-i|--images path] tar.gz generated by docker save."
    echo "  [-r|--registry registry:port] target private registry:port."
    echo "  [--windows-image-list path] text file with list of images used in Windows. Windows image mirroring is skipped when this is empty"
    echo "  [--windows-versions version] Comma separated Windows versions. e.g., \"1809,1903\". (Default \"1903\")"
    echo "  [-h|--help] Usage message"
}

push_manifest () {
    export DOCKER_CLI_EXPERIMENTAL=enabled
    manifest_list=()
    for i in "${arch_list[@]}"
    do
        manifest_list+=("$1-${i}")
    done

    echo "Preparing manifest $1, list[${arch_list[@]}]"
    docker manifest create "$1" "${manifest_list[@]}" --amend
    docker manifest push "$1" --purge
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--registry)
        reg="$2"
        shift # past argument
        shift # past value
        ;;
        -l|--image-list)
        list="$2"
        shift # past argument
        shift # past value
        ;;
        -i|--images)
        images="$2"
        shift # past argument
        shift # past value
        ;;
        --windows-image-list)
        windows_image_list="$2"
        shift # past argument
        shift # past value
        ;;
        --windows-versions)
        windows_versions="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        help="true"
        shift
        ;;
        *)
        usage
        exit 1
        ;;
    esac
done
if [[ -z $reg ]]; then
    usage
    exit 1
fi
if [[ $help ]]; then
    usage
    exit 0
fi

docker load --input ${images}

linux_images=()
while IFS= read -r i; do
    [ -z "${i}" ] && continue
    linux_images+=("${i}");
done < "${list}"

arch_list=()
if [[ -n "${windows_image_list}" ]]; then
    IFS=',' read -r -a versions <<< "$windows_versions"
    for version in "${versions[@]}"
    do
        arch_list+=("windows-${version}")
    done

    windows_images=()
    while IFS= read -r i; do
        [ -z "${i}" ] && continue
        windows_images+=("${i}")
    done < "${windows_image_list}"

    # use manifest to publish images only used in Windows
    for i in "${windows_images[@]}"; do
        if [[ ! " ${linux_images[@]}" =~ " ${i}" ]]; then
            case $i in
            */*)
                image_name="${reg}/${i}"
                ;;
            *)
                image_name="${reg}/rancher/${i}"
                ;;
            esac
            push_manifest "${image_name}"
        fi
    done
fi


arch_list+=("linux-amd64")
for i in "${linux_images[@]}"; do
    [ -z "${i}" ] && continue
    arch_suffix=""
    use_manifest=false
    if [[ (-n "${windows_image_list}") && " ${windows_images[@]}" =~ " ${i}" ]]; then
        # use manifest to publish images when it is used both in Linux and Windows
        use_manifest=true
        arch_suffix="-linux-amd64"
    fi
    case $i in
    */*)
        image_name="${reg}/${i}"
        ;;
    *)
        image_name="${reg}/rancher/${i}"
        ;;
    esac

    docker tag "${i}" "${image_name}${arch_suffix}"
    docker push "${image_name}${arch_suffix}"

    if $use_manifest; then
        push_manifest "${image_name}"
    fi
done
