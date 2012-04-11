package away3d.loaders.parsers
{
	import away3d.arcane;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.ColorMaterial;
	import away3d.materials.TextureMaterial;
	import away3d.materials.lightpickers.StaticLightPicker;
	import away3d.textures.Texture2DBase;
	
	import com.mgsoft.mg3dengine.FilePath;
	import com.mgsoft.mg3dengine.MG3DGlobals;
	import com.mgsoft.mg3dengine.MGColorUtils;
	
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	import flash.net.URLRequest;
	
	import mx.utils.ColorUtil;
	

	use namespace arcane;
	
	/**
	 * OBJParser provides a parser for the OBJ data type.
	 */
	public class TGCParser extends ParserBase
	{
		private var _xmlData:XML;
		
		private var _startedParsing : Boolean;
		private var _parsedMeshes:Boolean;
		private var _parsedMaterials:Boolean;
		private var _current_mesh:int;
		private var _materials : Vector.<TextureMaterial>;
		
		/**
		 * Loads a Viewer.dat Lepton File.
		 */
		public function TGCParser()
		{
			super(ParserDataFormat.PLAIN_TEXT);			
		}
		
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension : String) : Boolean
		{
			extension = extension.toLowerCase();
			return extension == "xml";
		}
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency:ResourceDependency):void
		{
			if (resourceDependency.assets.length != 1)
				return;
			
			var asset : Texture2DBase = resourceDependency.assets[0] as Texture2DBase;
			
			var index : int = int(resourceDependency.id);
			
			_materials[index].texture = asset;
				
		}
		
		/**
		* @inheritDoc
		*/
		override arcane function resolveDependencyFailure(resourceDependency:ResourceDependency):void
		{
			
		}
		
		/**
		* @inheritDoc
		*/
		override protected function proceedParsing() : Boolean
		{
			if(!_startedParsing)
				_xmlData = new XML(getTextData());
			
			
			if(!_startedParsing){
				_startedParsing = true;
				_materials = new Vector.<TextureMaterial>();
				_current_mesh = 0;
			}
			
			if (!_parsedMaterials) {
				parseMaterials();
			}				
			else
			{
				parseMeshes();
				if (_parsedMeshes)
					return PARSING_DONE;
			}
			
			return MORE_TO_PARSE;
		}
		
		private function parseMaterials():void
		{
			//busco el tag <materials>
			var materialsTag : XML = _xmlData.materials[0];
			var cant_materials : int  = int(materialsTag.@count);
			for each (var matTag:XML in materialsTag.m) 
			{
				var mat : TextureMaterial = new TextureMaterial();
				//TODO: Este mat.ambient es un number
				//REVEER Todos los parametros del material
				mat.ambient = parseColor(matTag.ambient);
				mat.diffuseLightSources = parseColor(matTag.diffuse);
				mat.specularColor = parseColor(matTag.specular);
				mat.bothSides = true;
				//matTag.opacity <opacity>100.0</opacity>
				mat.alpha = Number(matTag.opacity)/100;
				
				//va la dependencia de la textura
				addDependency(_materials.length.toString(10), new URLRequest("textures/" + matTag.bitmap));
				
				_materials.push(mat);
			}
			
			_parsedMaterials = true;
		}
		
		protected function parseMeshes():void
		{
			//Meshes
			//<mesh name='Object03' pos='[0.124254,-3.10714,66.3222]' matId='0' color='[87.0,225.0,87.0]' visibility='1.0' lightmap=''>
			//<coordinatesIdx count='6'>1 11 10 10 0 1 </coordinatesIdx>
			//<textCoordsIdx count='4'>2 22 20 20 </textCoordsIdx>
			//<colorsIdx count='8'>0 0 0 0 0 0 0 0 </colorsIdx>
			//<matIds count='1'>0</matIds>
			//<vertices count='3'>3.42936 91.7357 0.0574665 </vertices>
			//<normals count='3'>1.0 2.09466e-007 -6.86202e-006 </normals>
			//<texCoords count='2'>0.783176 -0.0309296 </texCoords> <texCoords count='5628'>0.783176 -0.0309296 </texCoords>
			//<colors count='3'>255 255 255 </colors> <colors count='3'>r g b </colors>
			
			var _cant_meshes:int = int(_xmlData.meshes[0].@count);
			var meshTag : XML = _xmlData.meshes[0].mesh[_current_mesh];
			var geometry : Geometry = new Geometry();
			var mesh : Mesh = new Mesh(geometry);
			var subGeometry : SubGeometry = new SubGeometry();
			
			var coordinatesIdx : Vector.<Number> = parseFloatList(meshTag.coordinatesIdx);
			var textCoordsIdx : Vector.<Number> = parseFloatList(meshTag.textCoordsIdx);
			var vertices : Vector.<Number> = parseFloatList(meshTag.vertices);
			var normals : Vector.<Number> = parseFloatList(meshTag.normals);
			var texCoords : Vector.<Number> = parseFloatList(meshTag.texCoords);
			
			var mvertices : Vector.<Number> = new Vector.<Number>();
			var mnormals : Vector.<Number> = new Vector.<Number>();
			var mtexCoords : Vector.<Number> = new Vector.<Number>();
			var mindex : Vector.<uint> = new Vector.<uint>();
			
			/*for each (var i:int in coordinatesIdx) 
			{	
				mvertices.push(vertices[i*3]*10, vertices[i*3 + 1]*10, vertices[i*3 + 2]*10);
				mnormals.push(normals[i*3], normals[i*3 + 1], normals[i*3 + 2]);
			}
			
			for each (i in textCoordsIdx) 
			{	
				mtexCoords.push(texCoords[i*2], texCoords[i*2 + 1]);
			}
			
			for (var j:int = 0; j < mvertices.length; j++) 
			{
				mindex.push(j);					
			}*/
			
			for (var i:int = 0; i < vertices.length/3; i++) 
			{
				mvertices.push(vertices[i*3]*10, vertices[i*3 + 1]*10, vertices[i*3 + 2]*10);
				mnormals.push(normals[i*3], normals[i*3 + 1], normals[i*3 + 2]);
				mtexCoords.push(texCoords[i*2], texCoords[i*2 + 1]);
			}
			
			for each (var j:int in coordinatesIdx) 
			{
				mindex.push(j);					
			}
			
			mesh.material = _materials[0];
			subGeometry.updateVertexData(mvertices);
			subGeometry.updateVertexNormalData(mnormals);
			subGeometry.updateUVData(mtexCoords);
			subGeometry.updateIndexData(mindex);
			
			geometry.addSubGeometry(subGeometry);
			
			mesh.showBounds = true;
			
			finalizeAsset(mesh);		
			
			_current_mesh++;			
			if(_current_mesh >= _cant_meshes)
				_parsedMeshes = true;
		}
		
		/**
		 * Parsea un vector con formato [float,float,float,float], [float,float,float], [float,float], [float] 
		 * Soporta hasta 4 valores y los devuelve en las propiedades
		 * de la clase Vector3D como X,Y,Z,W correspondientemente
		 */
		protected function parseVector(str : String):Vector3D
		{
			var rta : Vector3D = new Vector3D();
			var nums : Vector.<Number> = parseFloatList(str);
			
			if(nums.length > 0)
				rta.x = nums[0];
			
			if(nums.length > 1)
				rta.y = nums[1];
			
			if(nums.length > 2)
				rta.z = nums[2];
			
			if(nums.length > 3)
				rta.w = nums[3];
			
			return rta;
		}
		
		/**
		 * Parsea un vector con formato [r,g,b,a] 
		 * Devuelve el Number del color
		 */
		protected function parseColor(str : String):uint
		{
			var nums : Vector.<Number> = parseFloatList(str);
			
			return MGColorUtils.colorFromARGB(nums[0],nums[1],nums[2],nums[3]);
		}
		
		
		
		/**
		 * Parsea una lista de floats con separacion por espacion o comas.
		 * Ej1: 512.2 125.1 5 2 8
		 * Ej2: 512.2,125.1,5,2,8  
		 */
		protected function parseFloatList(str : String):Vector.<Number>
		{
			var rta : Vector.<Number> = new Vector.<Number>();
			str = str.replace(/\[/g, "").replace(/\]/g, "").replace(/\"/g,"").replace(/\,/g," ");
			
			for each (var num:String in str.split(" "))
			{
				if(num != "")
					rta.push(Number(num));				
			}
			
			
			return rta;
		}
		
	}
}
		

