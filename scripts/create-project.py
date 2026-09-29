#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; run only when regenerating it."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
objects=[]
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(name,body):
    objects.append(f'{ident(name)} = {{ {body} }};');return ident(name)
def ref(name):return ident(name)
def config(name, settings):return obj(name,'isa = XCBuildConfiguration; buildSettings = { '+settings+' }; name = '+name.split('-')[-1]+';')
def configs(prefix,common,debug='',release=''):
    a=config(prefix+'-Debug',common+debug);b=config(prefix+'-Release',common+release)
    return obj(prefix+'-configs',f'isa = XCConfigurationList; buildConfigurations = ({a}, {b}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
appSources=[];testSources=[];fileRefs={}
for folder,target,out in [('finder-fixer','app',appSources),('finder-fixerTests','tests',testSources)]:
    for p in sorted((root/folder).rglob('*.swift')):
        path=p.relative_to(root).as_posix()
        f=obj(path,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT;')
        fileRefs[path] = f
        out.append(obj(path+'-build',f'isa = PBXBuildFile; fileRef = {f};'))
assetPath='finder-fixer/Resources/Assets.xcassets'
assetRef=obj(assetPath,f'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "{assetPath}"; sourceTree = SOURCE_ROOT;')
fileRefs[assetPath] = assetRef
assetBuild=obj(assetPath+'-build',f'isa = PBXBuildFile; fileRef = {assetRef};')
appProduct=obj('app-product','isa = PBXFileReference; explicitFileType = wrapper.application; path = "finder-fixer.app"; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=obj('test-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = "finder-fixerTests.xctest"; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = ({appProduct}, {testProduct}); name = Products; sourceTree = "<group>";')
def source_group(folder):
    """Mirror source directories in Xcode without moving files on disk."""
    children = []
    subfolders = sorted({
        folder + '/' + path[len(folder) + 1:].split('/')[0]
        for path in fileRefs
        if path.startswith(folder + '/') and '/' in path[len(folder) + 1:]
    })
    for subfolder in subfolders:
        children.append(source_group(subfolder))
    children.extend(file for path, file in fileRefs.items() if str(Path(path).parent) == folder)
    return obj('group-' + folder,
               f'isa = PBXGroup; children = ({", ".join(children)}); '
               f'name = "{Path(folder).name}"; sourceTree = "<group>";')

appGroup = source_group('finder-fixer')
testsGroup = source_group('finder-fixerTests')
main=obj('main',f'isa = PBXGroup; children = ({appGroup}, {testsGroup}, {products}); sourceTree = "<group>";')
common='CLANG_ENABLE_MODULES = YES; MACOSX_DEPLOYMENT_TARGET = 13.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CODE_SIGN_STYLE = Manual; CODE_SIGN_IDENTITY = "-"; '
pc=configs('project',common,'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; ','SWIFT_COMPILATION_MODE = wholemodule; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; ')
ac=configs('app','ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; PRODUCT_NAME = "finder-fixer"; PRODUCT_MODULE_NAME = finder_fixer; PRODUCT_BUNDLE_IDENTIFIER = "local.finder-fixer"; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = "finder-fixer"; INFOPLIST_KEY_LSUIElement = YES; INFOPLIST_KEY_NSHumanReadableCopyright = ""; ENABLE_APP_SANDBOX = NO; ENABLE_HARDENED_RUNTIME = YES; CURRENT_PROJECT_VERSION = 2; MARKETING_VERSION = 0.1.1; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks"; ')
tc=configs('tests','MACOSX_DEPLOYMENT_TARGET = 14.0; PRODUCT_NAME = "finder-fixerTests"; PRODUCT_BUNDLE_IDENTIFIER = "local.finder-fixer.tests"; GENERATE_INFOPLIST_FILE = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/finder-fixer.app/Contents/MacOS/finder-fixer"; BUNDLE_LOADER = "$(TEST_HOST)"; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks"; ')
for name,sources in [('app',appSources),('tests',testSources)]:
    obj(name+'-sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(sources)}); runOnlyForDeploymentPostprocessing = 0;')
    for phase in ['Frameworks','Resources']:
        resources=assetBuild if name=='app' and phase=='Resources' else ''
        obj(name+phase,f'isa = PBX{phase}BuildPhase; buildActionMask = 2147483647; files = ({resources}); runOnlyForDeploymentPostprocessing = 0;')
proxy=obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {ref("project")}; proxyType = 1; remoteGlobalIDString = {ref("app")}; remoteInfo = "finder-fixer";')
dep=obj('dependency',f'isa = PBXTargetDependency; target = {ref("app")}; targetProxy = {proxy};')
for name,product,conf in [('app',appProduct,ac),('tests',testProduct,tc)]:
    title='finder-fixer' if name=='app' else 'finder-fixerTests'
    typ='com.apple.product-type.application' if name=='app' else 'com.apple.product-type.bundle.unit-test'
    obj(name,f'isa = PBXNativeTarget; buildConfigurationList = {conf}; buildPhases = ({ref(name+"-sources")}, {ref(name+"Frameworks")}, {ref(name+"Resources")}); buildRules = (); dependencies = ({dep if name=="tests" else ""}); name = "{title}"; productName = "{title}"; productReference = {product}; productType = "{typ}";')
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (en, Base, "zh-Hans"); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({ref("app")}, {ref("tests")});')
project=root/'finder-fixer.xcodeproj';project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(objects)+f'\n}}; rootObject = {ref("project")}; }}\n')
def buildref(name,title,product):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(name)}" BuildableName="{product}" BlueprintName="{title}" ReferencedContainer="container:finder-fixer.xcodeproj"/>'
a=buildref('app','finder-fixer','finder-fixer.app');t=buildref('tests','finder-fixerTests','finder-fixerTests.xctest')
scheme=project/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
(scheme/'finder-fixer.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{a}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{t}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated project with',len(appSources),'app files and',len(testSources),'test files')
