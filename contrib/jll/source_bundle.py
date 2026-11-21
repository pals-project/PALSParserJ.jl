"""Produce complete corresponding source from the exact revisions in the recipe."""
import pathlib
import shutil
import subprocess
import tarfile
import tempfile

pins = {
    "PALSParserCpp": ("pals-project/PALSParserCpp", "949c29462204c46d0c520e41dea0c582a8adcb8b"),
    "rapidyaml": ("biojppm/rapidyaml", "119b6042064d3828819e428e32e5a0f3035d5643"),
    "pcre2": ("PCRE2Project/pcre2", "6ae58beca071f13ccfed31d03b3f479ab520639b"),
    "AtomicAndPhysicalConstantsCLib": ("pals-project/AtomicAndPhysicalConstantsCLib", "7d16dd842f1f50cdda9e0f1da86ee56a5a2b6232"),
}
root = pathlib.Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as work:
    tree = pathlib.Path(work) / "PALSParserCpp-corresponding-source"
    tree.mkdir()
    for name, (repo, revision) in pins.items():
        target = tree / name
        subprocess.run(["git", "init", "--quiet", str(target)], check=True)
        subprocess.run(["git", "-C", str(target), "remote", "add", "origin", f"https://github.com/{repo}.git"], check=True)
        subprocess.run(["git", "-C", str(target), "fetch", "--quiet", "--depth=1", "origin", revision], check=True)
        subprocess.run(["git", "-C", str(target), "checkout", "--quiet", "--detach", "FETCH_HEAD"], check=True)
        subprocess.run(["git", "-C", str(target), "submodule", "update", "--init", "--recursive"], check=True)
        shutil.rmtree(target / ".git")
        for p in target.rglob(".git"):
            if p.is_dir():
                shutil.rmtree(p)
            else:
                p.unlink()
    shutil.copytree(root, tree / "packaging", ignore=shutil.ignore_patterns("products", "build", "Manifest.toml", "__pycache__"))
    output = root / "products" / "PALSParserCpp-corresponding-source.tar.gz"
    output.parent.mkdir(exist_ok=True)
    with tarfile.open(output, "w:gz") as archive:
        archive.add(tree, arcname=tree.name)
    print(output)
