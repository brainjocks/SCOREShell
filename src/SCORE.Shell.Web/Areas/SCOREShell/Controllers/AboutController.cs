using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Web;
using System.Web.Mvc;

namespace SCORE.Shell.Web.Areas.SCOREShell.Controllers
{
    public class AboutController
    {
        public AboutController()
        {
        }

        protected Dictionary<string, object> _info = new Dictionary<string, object>();

        public List<string> Assemblies
        {
            get
            {
                return FindAssemblies().ToList();
            }
        }

        // returns all .dll files that begin with 'AcmeCo' in the current executing application
        private IEnumerable<string> FindAssemblies()
        {
            var binDirectory = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bin");

            // Find all DLLs that are AcmeCo.*.dll
            var dlls = Directory.GetFiles(binDirectory)
                .Where(x =>
                    !string.IsNullOrEmpty(x)
                    && Path.GetFileName(x).EndsWith(".dll")
                    && Path.GetFileName(x).StartsWith("SCORE.Shell"))
                .Select(Path.GetFileNameWithoutExtension);

            return dlls;
        }

        protected void AddInfo(string key, object value)
        {
            _info.Add(key, value);
            
        }

        private void LoadAboutInfo()
        {
            foreach (string assembly in FindAssemblies())
            {
                Assembly dll = Assembly.Load(assembly);

                Version version = dll.GetName().Version;
                FileVersionInfo info = FileVersionInfo.GetVersionInfo(dll.Location);

                _info.Add(assembly, new
                {
                    Version = version.ToString(),
                    Build = info.FileVersion
                });
            }
        }

        [HttpGet]
        public virtual ActionResult Version()
        {
            return new JsonResult
            {
                Data = _info,
                JsonRequestBehavior = JsonRequestBehavior.AllowGet
            };
        }
    }
}