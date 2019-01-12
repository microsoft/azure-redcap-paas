using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;

namespace RedCAP.Scheduler
{
    public class Functions
    {
        // This function will get triggered/executed every hour on a schedule
        [NoAutomaticTrigger]
        public static void InvokeCronJob(TextWriter log)
        {
            try
            {
                var url = string.Format("https://{0}/cron.php", Environment.GetEnvironmentVariable("WEBSITE_HOSTNAME"));
                using (var web = new WebClient())
                {
                    web.DownloadString(url);
                }
            }
            catch (Exception ex)
            {
                log.WriteLine("Scheduled Job failed: " + ex.Message);
                throw;
            }
        }
    }
}
