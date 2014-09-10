﻿using System;
using System.Linq;
using System.Reflection;

namespace Microsoft.AspNet.SignalR.Client
{
    /// <summary>
    ///     Provides an extension method for hubproxies.
    /// </summary>
    public static class HubProxyExtension
    {
        /// <summary>
        ///     Subscribes on all events (methods) which the server can call.
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="hubProxy"></param>
        /// <param name="instance"></param>
        /// <exception cref="NotSupportedException"></exception>
        public static void SubscribeOn<T>(this object hubProxy, object instance) where T : class
        {
            if (!(hubProxy is IHubProxy) && hubProxy.GetType().BaseType != typeof (InterfaceHubProxyBase))
            {
                throw new NotSupportedException("This method can only be called for HubProxies.");
            }

            var theRealHubProxy = hubProxy as IHubProxy;
            if (theRealHubProxy == null)
            {
                FieldInfo fieldInfo = hubProxy.GetType()
                    .GetField("_hubProxy", BindingFlags.NonPublic | BindingFlags.Instance);

                if (fieldInfo == null)
                {
                    // should never happen
                    throw new Exception("Something went wrong -.-");
                }
                theRealHubProxy = (IHubProxy) fieldInfo.GetValue(hubProxy);
            }

            Type interfaceType = typeof (T);

            if (!interfaceType.IsInterface)
            {
                throw new NotSupportedException("T is not an interface.");
            }

            MethodInfo[] methodInfos = interfaceType.GetMethods();

            foreach (MethodInfo methodInfo in methodInfos)
            {
                ParameterInfo[] parameterInfos = methodInfo.GetParameters();

                if (parameterInfos.Count() > 7)
                {
                    throw new NotSupportedException(
                        string.Format(
                            "Only interface methods with less or equal 7 parameters are supported: {0}.{1}({2})!",
                            // ReSharper disable once PossibleNullReferenceException
                            methodInfo.DeclaringType.FullName.Replace("+", "."),
                            methodInfo.Name,
                            string.Join(", ",
                                methodInfo.GetParameters()
                                    .Select(p => string.Format("{0} {1}", p.ParameterType.Name, p.Name)))));
                }

                MethodInfo onMethod;
                Type actionType;

                if (parameterInfos.Any())
                {
                    onMethod =
                        typeof (HubProxyExtensions).GetMethods(BindingFlags.Static | BindingFlags.Public)
                            .First(
                                m => m.Name.Equals("On") && m.GetGenericArguments().Length == parameterInfos.Length);

                    onMethod = onMethod.MakeGenericMethod(parameterInfos.Select(pi => pi.ParameterType).ToArray());
                    actionType = typeof (Action<>).MakeGenericType(parameterInfos.Select(p => p.ParameterType).ToArray());
                }
                else
                {
                    onMethod =
                        typeof (HubProxyExtensions).GetMethods(BindingFlags.Static | BindingFlags.Public)
                            .First(
                                m => m.Name.Equals("On") && m.GetGenericArguments().Length == 0);

                    actionType = typeof (Action);
                }

                Delegate actionDelegate = Delegate.CreateDelegate(actionType, instance, methodInfo);


                onMethod.Invoke(null, new object[] {theRealHubProxy, methodInfo.Name, actionDelegate});
            }
        }
    }
}