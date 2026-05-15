const buildForFile = process.env.BUILD_FOR_FILE === '1';
const lowMemoryBuild = process.env.HOROSA_LOW_MEMORY_BUILD === '1'
	|| process.env.DIGITALOCEAN_APP_PLATFORM === '1';
const publicPath = process.env.HOROSA_PUBLIC_PATH || (buildForFile ? './' : '/');

export default {
	publicPath: publicPath,
	outputPath: buildForFile ? 'dist-file' : 'dist',
	history: buildForFile ? { type: 'hash' } : undefined,
	hash: true,
	dva: {
		immer: false,
	},
	antd: {},
	dynamicImport: false,
	dll: false,
	hardSource: false,
	pwa: false,
	hd: false,
	fastClick: false,
	define: {
		'process.env.HOROSA_PUBLIC_SERVER_ROOT': process.env.HOROSA_PUBLIC_SERVER_ROOT || '',
		'process.env.UMI_APP_SERVER_ROOT': process.env.UMI_APP_SERVER_ROOT || '',
	},
	title: '星阙 - 玄学与星座云平台',
	chainWebpack(config) {
		// App Platform's standard builders can be memory constrained. These
		// cache groups keep heavyweight optional workspaces out of the entry chunk
		// without removing any runtime feature.
		if (lowMemoryBuild) {
			config.optimization.splitChunks({
				chunks: 'all',
				minSize: 20000,
				maxAsyncRequests: 30,
				maxInitialRequests: 20,
				cacheGroups: {
					reactVendor: {
						test: /[\\/]node_modules[\\/](react|react-dom|dva|umi|@umijs)[\\/]/,
						name: 'vendor-react',
						priority: 50,
						enforce: true,
					},
					antdVendor: {
						test: /[\\/]node_modules[\\/](@ant-design|antd|antd-mobile|rc-[^\\/]+)[\\/]/,
						name: 'vendor-antd',
						priority: 40,
						enforce: true,
					},
					astro3dVendor: {
						test: /[\\/]node_modules[\\/](three)[\\/]/,
						name: 'vendor-astro3d',
						priority: 35,
						enforce: true,
					},
					mediaVendor: {
						test: /[\\/]node_modules[\\/](video\.js|videojs-flash|flv\.js)[\\/]/,
						name: 'vendor-media',
						priority: 35,
						enforce: true,
					},
					exportVendor: {
						test: /[\\/]node_modules[\\/](docx|jszip|mammoth)[\\/]/,
						name: 'vendor-export',
						priority: 35,
						enforce: true,
					},
					defaultVendors: {
						test: /[\\/]node_modules[\\/]/,
						name: 'vendor',
						priority: -10,
						reuseExistingChunk: true,
					},
				},
			});
		}
	},
}
