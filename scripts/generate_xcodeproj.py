#!/usr/bin/env python3
"""Generate a minimal AppVolume.xcodeproj for the macOS menu bar app."""

from __future__ import annotations

import os
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "AppVolume"
TESTS = ROOT / "AppVolumeTests"
PROJ = ROOT / "AppVolume.xcodeproj"


def nid() -> str:
    return uuid.uuid4().hex[:24].upper()


def collect_files(base: Path, pattern: str) -> list[Path]:
    return sorted(base.rglob(pattern))


swift_files = [p for p in collect_files(SRC, "*.swift") if "AppVolumeTests" not in str(p)]
test_files = collect_files(TESTS, "*.swift")
resource_files = [
    SRC / "Resources" / "Assets.xcassets",
]

# Stable-ish IDs
project_id = nid()
main_group = nid()
products_group = nid()
src_group = nid()
tests_group = nid()
resources_group = nid()
frameworks_group = nid()
target_id = nid()
test_target_id = nid()
sources_phase = nid()
resources_phase = nid()
frameworks_phase = nid()
test_sources_phase = nid()
test_frameworks_phase = nid()
project_config_list = nid()
target_config_list = nid()
test_config_list = nid()
debug_project = nid()
release_project = nid()
debug_target = nid()
release_target = nid()
debug_test = nid()
release_test = nid()
app_product = nid()
tests_product = nid()

file_refs: dict[Path, str] = {}
build_files: dict[Path, str] = {}

for path in swift_files + test_files + resource_files:
    file_refs[path] = nid()
    build_files[path] = nid()

# Build nested groups by relative folder
folder_groups: dict[str, str] = {"": src_group}
group_children: dict[str, list[str]] = {"": []}


def ensure_group(rel: str) -> str:
    if rel in folder_groups:
        return folder_groups[rel]
    parent_rel = str(Path(rel).parent) if Path(rel).parent.as_posix() != "." else ""
    if parent_rel == ".":
        parent_rel = ""
    parent_id = ensure_group(parent_rel)
    gid = nid()
    folder_groups[rel] = gid
    group_children.setdefault(rel, [])
    group_children.setdefault(parent_rel, []).append(gid)
    return gid


for path in swift_files:
    rel_dir = path.relative_to(SRC).parent.as_posix()
    if rel_dir == ".":
        rel_dir = ""
    gid = ensure_group(rel_dir)
    group_children.setdefault(rel_dir, []).append(file_refs[path])

# Info.plist, entitlements, assets under Resources
info_plist = SRC / "Resources" / "Info.plist"
entitlements = SRC / "Resources" / "AppVolume.entitlements"
info_ref = nid()
ent_ref = nid()
file_refs[info_plist] = info_ref
file_refs[entitlements] = ent_ref
assets_ref = file_refs[SRC / "Resources" / "Assets.xcassets"]
ensure_group("Resources")
group_children.setdefault("Resources", [])
group_children["Resources"].extend([info_ref, ent_ref, assets_ref])

# Tests
test_children = [file_refs[p] for p in test_files]

lines: list[str] = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")
lines.append("")

# PBXBuildFile
lines.append("/* Begin PBXBuildFile section */")
for path in swift_files:
    lines.append(
        f"\t\t{build_files[path]} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};"
    )
for path in test_files:
    lines.append(
        f"\t\t{build_files[path]} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};"
    )
assets = SRC / "Resources" / "Assets.xcassets"
lines.append(
    f"\t\t{build_files[assets]} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs[assets]} /* Assets.xcassets */; }};"
)
lines.append("/* End PBXBuildFile section */")
lines.append("")

# PBXFileReference
lines.append("/* Begin PBXFileReference section */")
lines.append(
    f"\t\t{app_product} /* AppVolume.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AppVolume.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
)
lines.append(
    f"\t\t{tests_product} /* AppVolumeTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = AppVolumeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};"
)
for path in swift_files:
    rel = path.relative_to(ROOT).as_posix()
    lines.append(
        f"\t\t{file_refs[path]} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {path.name}; sourceTree = \"<group>\"; }};"
    )
for path in test_files:
    lines.append(
        f"\t\t{file_refs[path]} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {path.name}; sourceTree = \"<group>\"; }};"
    )
lines.append(
    f"\t\t{file_refs[assets]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};"
)
lines.append(
    f"\t\t{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};"
)
lines.append(
    f"\t\t{ent_ref} /* AppVolume.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = AppVolume.entitlements; sourceTree = \"<group>\"; }};"
)
lines.append("/* End PBXFileReference section */")
lines.append("")

# Groups
lines.append("/* Begin PBXGroup section */")
lines.append(f"\t\t{main_group} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{src_group} /* AppVolume */,")
lines.append(f"\t\t\t\t{tests_group} /* AppVolumeTests */,")
lines.append(f"\t\t\t\t{products_group} /* Products */,")
lines.append("\t\t\t);")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{products_group} /* Products */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{app_product} /* AppVolume.app */,")
lines.append(f"\t\t\t\t{tests_product} /* AppVolumeTests.xctest */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Products;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

# Emit folder groups with path names
# Map group id -> (name/path, children)
# Root src group path = AppVolume
for rel, gid in folder_groups.items():
    children = group_children.get(rel, [])
    # unique preserve order
    seen = set()
    ordered = []
    for c in children:
        if c not in seen:
            seen.add(c)
            ordered.append(c)
    name = "AppVolume" if rel == "" else Path(rel).name
    path = "AppVolume" if rel == "" else Path(rel).name
    lines.append(f"\t\t{gid} /* {name} */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for c in ordered:
        # find name for comment
        comment = c
        for p, ref in file_refs.items():
            if ref == c:
                comment = p.name
                break
        for r, g in folder_groups.items():
            if g == c:
                comment = Path(r).name if r else "AppVolume"
                break
        lines.append(f"\t\t\t\t{c} /* {comment} */,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tpath = {path};")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

# Dedicated Resources group is already under folder_groups["Resources"] if ensure_group called
# But we also appended resources_group id incorrectly - remove that approach.
# Actually we set group_children[""].append(resources_group) but resources_group is unused empty.
# Clean: don't use resources_group separately since Resources is under folder_groups.

lines.append(f"\t\t{tests_group} /* AppVolumeTests */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for c in test_children:
    name = next(p.name for p, ref in file_refs.items() if ref == c)
    lines.append(f"\t\t\t\t{c} /* {name} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = AppVolumeTests;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")
lines.append("/* End PBXGroup section */")
lines.append("")

# Native targets
lines.append("/* Begin PBXNativeTarget section */")
lines.append(f"\t\t{target_id} /* AppVolume */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"AppVolume\" */;" % target_config_list)
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = AppVolume;")
lines.append("\t\t\tproductName = AppVolume;")
lines.append(f"\t\t\tproductReference = {app_product} /* AppVolume.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")

lines.append(f"\t\t{test_target_id} /* AppVolumeTests */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"AppVolumeTests\" */;" % test_config_list)
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{test_sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{test_frameworks_phase} /* Frameworks */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = AppVolumeTests;")
lines.append("\t\t\tproductName = AppVolumeTests;")
lines.append(f"\t\t\tproductReference = {tests_product} /* AppVolumeTests.xctest */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")
lines.append("")

# Project
lines.append("/* Begin PBXProject section */")
lines.append(f"\t\t{project_id} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append("\t\t\t\tLastSwiftUpdateCheck = 1640;")
lines.append("\t\t\t\tLastUpgradeCheck = 1640;")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"AppVolume\" */;")
lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
lines.append("\t\t\tdevelopmentRegion = en;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {main_group};")
lines.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
lines.append("\t\t\tprojectDirPath = \"\";")
lines.append("\t\t\tprojectRoot = \"\";")
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{target_id} /* AppVolume */,")
lines.append(f"\t\t\t\t{test_target_id} /* AppVolumeTests */,")
lines.append("\t\t\t);")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")
lines.append("")

# Resources build phase
lines.append("/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{resources_phase} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{build_files[assets]} /* Assets.xcassets in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")
lines.append("")

# Sources
lines.append("/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{sources_phase} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in swift_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{test_sources_phase} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in test_files:
    lines.append(f"\t\t\t\t{build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")
lines.append("")

# Frameworks empty
lines.append("/* Begin PBXFrameworksBuildPhase section */")
for phase in (frameworks_phase, test_frameworks_phase):
    lines.append(f"\t\t{phase} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
lines.append("/* End PBXFrameworksBuildPhase section */")
lines.append("")

# XCBuildConfiguration
common_project = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.2;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_VERSION = 5.0;
"""

lines.append("/* Begin XCBuildConfiguration section */")
lines.append(f"\t\t{debug_project} /* Debug */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(common_project)
lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Debug;")
lines.append("\t\t};")

lines.append(f"\t\t{release_project} /* Release */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(common_project.replace("ONLY_ACTIVE_ARCH = YES;", "ONLY_ACTIVE_ARCH = NO;"))
lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Release;")
lines.append("\t\t};")

target_settings = f"""
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = AppVolume/Resources/AppVolume.entitlements;
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = AppVolume/Resources/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.2;
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = local.appvolume;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
"""

for cfg_id, name in ((debug_target, "Debug"), (release_target, "Release")):
    lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append(target_settings)
    if name == "Debug":
        lines.append("\t\t\t\tENABLE_TESTABILITY = YES;")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")

test_settings = f"""
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.2;
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = local.appvolume.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AppVolume.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/AppVolume";
"""

for cfg_id, name in ((debug_test, "Debug"), (release_test, "Release")):
    lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append(test_settings)
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")

lines.append("/* End XCBuildConfiguration section */")
lines.append("")

# Config lists
lines.append("/* Begin XCConfigurationList section */")
lines.append(f"\t\t{project_config_list} /* Build configuration list for PBXProject \"AppVolume\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{debug_project} /* Debug */,")
lines.append(f"\t\t\t\t{release_project} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f"\t\t{target_config_list} /* Build configuration list for PBXNativeTarget \"AppVolume\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{debug_target} /* Debug */,")
lines.append(f"\t\t\t\t{release_target} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f"\t\t{test_config_list} /* Build configuration list for PBXNativeTarget \"AppVolumeTests\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{debug_test} /* Debug */,")
lines.append(f"\t\t\t\t{release_test} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")
lines.append("\t};")
lines.append(f"\trootObject = {project_id} /* Project object */;")
lines.append("}")

content = "\n".join(lines) + "\n"
PROJ.mkdir(parents=True, exist_ok=True)
(PROJ / "project.pbxproj").write_text(content, encoding="utf-8")
print(f"Wrote {PROJ / 'project.pbxproj'}")
print(f"Swift sources: {len(swift_files)}")
print(f"Tests: {len(test_files)}")
