import std, utile.logger, utile.except, utile.miniz : Zip;

auto getDir(string path)
{
	auto dirs = path.dirEntries(SpanMode.shallow).filter!(a => a.isDir)
		.map!(a => a.name)
		.filter!(a => a.baseName.startsWith(`10.`))
		.array
		.sort
		.release;

	dirs.length || throwError!`no versions found for %s`(path);

	if (dirs.length != 1)
		logger("too many versions for %s:\n%-(%s\n%)", path, dirs);

	auto res = dirs[$ - 1];

	logger(`using %s`, res);
	return res;
}

auto enumFiles(string path)
{
	return path.dirEntries(SpanMode.depth).filter!(a => a.isFile)
		.map!(a => a.name.toLower)
		.map!(a => tuple(a[path.length + 1 .. $].replace(`\`, `/`), a))
		.assocArray;
}

int main()
{
	try
	{
		// logger.info(`downloading vs installer`);
		// download(`https://download.visualstudio.microsoft.com/download/pr/befdb1f9-8676-4693-b031-65ee44835915/c541feeaa77b97681f7693fc5bed2ff82b331b168c678af1a95bdb1138a99802/vs_Community.exe`,
		// 		`vs_community.exe`);

		// logger.info(`installing build tools`);
		// [
		// 	`vs_community.exe`, `--add`,
		// 	`Microsoft.VisualStudio.Workload.NativeDesktop;includeRecommended`,
		// 	`-p`, `--norestart`, `--wait`
		// ].execute.status == 0 || throwError(`error while installing build tools`);

		const kitsVer = environment[`WindowsSDKVersion`];
		const kitsLibVer = environment[`WindowsSDKLibVersion`];

		kitsVer == kitsLibVer
			|| throwError!`different kit versions: sdk is %s, while libs are %s`(kitsVer,
					kitsLibVer);

		const kitsLibs = environment[`WindowsSdkDir`] ~ `Lib\` ~ kitsLibVer; //`C:\Program Files (x86)\Windows Kits\10\Lib`.getDir;
		const kitsIncludes = kitsLibs.replace(`\Lib\`, `\Include\`); //`C:\Program Files (x86)\Windows Kits\10\Include`.getDir;
		const msvc = environment[`VCToolsInstallDir`]; //`C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Tools\MSVC`.getDir;

		string[string] files;
		const kitsBin = environment[`WindowsSdkBinPath`];

		// foreach (arch; only(`x86`, `x64`))
		// 	foreach (file; only(`rc.exe`, `rcdll.dll`, `mt.exe`, `midlrtmd.dll`, `mt.exe.config`))
		// 		files[`bin/` ~ arch ~ '/' ~ file] = kitsBin ~ '/' ~ arch ~ '/' ~ file;
		foreach (file; only(`rc.exe`, `rcdll.dll`, `mt.exe`, `mt.exe.config`, `midlrtmd.dll`))
			files[`bin/` ~ file] = kitsBin ~ `/x86/` ~ file;

		foreach (file, path; enumFiles(kitsIncludes ~ `shared`))
			files[`include/` ~ file] = path;
		foreach (file, path; enumFiles(kitsIncludes ~ `um`))
			files[`include/` ~ file] = path;
		foreach (file, path; enumFiles(kitsIncludes ~ `ucrt`))
			files[`include/` ~ file] = path;

		foreach (file, path; enumFiles(kitsLibs ~ `um/x86`))
			files[`lib/x86/` ~ file] = path;
		foreach (file, path; enumFiles(kitsLibs ~ `um/x64`))
			files[`lib/x64/` ~ file] = path;

		foreach (file, path; enumFiles(kitsLibs ~ `ucrt/x86`))
			files[`lib/x86/` ~ file] = path;
		foreach (file, path; enumFiles(kitsLibs ~ `ucrt/x64`))
			files[`lib/x64/` ~ file] = path;

		foreach (file, path; enumFiles(msvc ~ `include`))
			files[`include/` ~ file] = path;
		foreach (file, path; enumFiles(msvc ~ `lib/x86`))
			files[`lib/x86/` ~ file] = path;
		foreach (file, path; enumFiles(msvc ~ `lib/x64`))
			files[`lib/x64/` ~ file] = path;

		scope zip = new Zip(`msvc_` ~ msvc.baseName ~ `.zip`, true, true);

		foreach (file, path; files)
			zip.put(file, path.read);

		return 0;
	}
	catch (Exception e)
	{
		logger.error(e);
	}

	return 1;
}
