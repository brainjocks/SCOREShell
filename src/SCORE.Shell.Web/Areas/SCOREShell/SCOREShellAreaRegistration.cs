using Sitecore.Mvc.Routing;
using System.Web.Mvc;
using System.Web.Routing;

namespace SCORE.Shell.Web.Areas.SCOREShell
{
    public class ScoreShellAreaRegistration : AreaRegistration
    {
        public override string AreaName
        {
            get
            {
                return "shell";
            }
        }

        public override void RegisterArea(AreaRegistrationContext context)
        {
            context.Namespaces.Add("SCORE.Shell.Web.Areas.SCOREShell.Controllers");

            var aboutRoute = context.MapRoute(
                "SCOREShell_about",
                "scoreshell/about/version",
                new { controller = "About", action = "Version"},
                new[] {"SCORE.Shell.Web.Areas.SCOREShell.Controllers"});

            aboutRoute.RouteHandler = new Sitecore.Mvc.Routing.RouteHandlerWrapper(aboutRoute.RouteHandler);
        }
    }
}