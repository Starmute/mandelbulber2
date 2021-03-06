/**
 * Mandelbulber v2, a 3D fractal generator       ,=#MKNmMMKmmßMNWy,
 *                                             ,B" ]L,,p%%%,,,§;, "K
 * Copyright (C) 2017-18 Mandelbulber Team     §R-==%w["'~5]m%=L.=~5N
 *                                        ,=mm=§M ]=4 yJKA"/-Nsaj  "Bw,==,,
 * This file is part of Mandelbulber.    §R.r= jw",M  Km .mM  FW ",§=ß., ,TN
 *                                     ,4R =%["w[N=7]J '"5=],""]]M,w,-; T=]M
 * Mandelbulber is free software:     §R.ß~-Q/M=,=5"v"]=Qf,'§"M= =,M.§ Rz]M"Kw
 * you can redistribute it and/or     §w "xDY.J ' -"m=====WeC=\ ""%""y=%"]"" §
 * modify it under the terms of the    "§M=M =D=4"N #"%==A%p M§ M6  R' #"=~.4M
 * GNU General Public License as        §W =, ][T"]C  §  § '§ e===~ U  !§[Z ]N
 * published by the                    4M",,Jm=,"=e~  §  §  j]]""N  BmM"py=ßM
 * Free Software Foundation,          ]§ T,M=& 'YmMMpM9MMM%=w=,,=MT]M m§;'§,
 * either version 3 of the License,    TWw [.j"5=~N[=§%=%W,T ]R,"=="Y[LFT ]N
 * or (at your option)                   TW=,-#"%=;[  =Q:["V""  ],,M.m == ]N
 * any later version.                      J§"mr"] ,=,," =="""J]= M"M"]==ß"
 *                                          §= "=C=4 §"eM "=B:m|4"]#F,§~
 * Mandelbulber is distributed in            "9w=,,]w em%wJ '"~" ,=,,ß"
 * the hope that it will be useful,                 . "K=  ,=RMMMßM"""
 * but WITHOUT ANY WARRANTY;                            .'''
 * without even the implied warranty
 * of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License
 * along with Mandelbulber. If not, see <http://www.gnu.org/licenses/>.
 *
 * ###########################################################################
 *
 * Authors: Krzysztof Marczak (buddhi1980@gmail.com)
 *
 * calculation of shadows from auxiliary light sources
 */

#ifdef AUX_LIGHTS
#if defined(SHADOWS) || defined(VOLUMETRIC_LIGHTS)
float AuxShadow(constant sClInConstants *consts, sRenderData *renderData, sShaderInputDataCl *input,
	float distance, float3 lightVector, sClCalcParams *calcParam)
{
	// float step = input.delta;
	float dist;
	float light;

	float opacity;
	float shadowTemp = 1.0f;

	float DE_factor = consts->params.DEFactor;
	if (consts->params.iterFogEnabled || consts->params.volumetricLightAnyEnabled) DE_factor = 1.0f;

	float softRange = tan(consts->params.shadowConeAngle / 180.0f * M_PI_F);
	float maxSoft = 0.0f;

	const bool bSoft =
		!consts->params.iterFogEnabled && !consts->params.common.iterThreshMode && softRange > 0.0f;

	int count = 0;
	float step = 0.0f;

	float iterFogSum = 0.0f;

	for (float i = input->delta; i < distance; i += step)
	{
		float3 point2 = input->point + lightVector * i;

		float dist_thresh;
		if (consts->params.iterFogEnabled || consts->params.volumetricLightAnyEnabled)
		{
			dist_thresh = CalcDistThresh(point2, consts);
		}
		else
			dist_thresh = input->distThresh;

		calcParam->distThresh = dist_thresh;
		formulaOut outF;

		outF = CalculateDistance(consts, point2, calcParam, renderData);
		dist = outF.distance;

		bool limitsAcheved = false;
#ifdef LIMITS_ENABLED
		limitsAcheved = any(isless(point2, consts->params.limitMin))
										|| any(isgreater(point2, consts->params.limitMax));
#endif // LIMITS_ENABLED

		if (bSoft && !limitsAcheved)
		{
			float angle = (dist - dist_thresh) / i;
			if (angle < 0.0f) angle = 0.0f;
			if (dist < dist_thresh) angle = 0.0f;
			float softShadow = 1.0f - angle / softRange;
			if (consts->params.penetratingLights) softShadow *= (distance - i) / distance;
			if (softShadow < 0.0f) softShadow = 0.0f;
			if (softShadow > maxSoft) maxSoft = softShadow;
		}

#ifdef ITER_FOG
		opacity =
			IterOpacity(dist * DE_factor, outF.iters, consts->params.N, consts->params.iterFogOpacityTrim,
				consts->params.iterFogOpacityTrimHigh, consts->params.iterFogOpacity);

		opacity *= (distance - i) / distance;
		opacity = min(opacity, 1.0f);
		iterFogSum = opacity + (1.0f - opacity) * iterFogSum;
#else
		opacity = 0.0f;
#endif

		shadowTemp = 1.0f - iterFogSum;

		if (dist < dist_thresh || shadowTemp <= 0.0f)
		{
			if (consts->params.penetratingLights)
			{
				shadowTemp -= (distance - i) / distance;
				if (shadowTemp < 0.0f) shadowTemp = 0.0f;
			}
			else
			{
				shadowTemp = 0.0f;
			}
			break;
		}

		step = dist * DE_factor;
		step = max(step, 1e-6f);

		count++;
		if (count > MAX_RAYMARCHING) break;
	}

	if (!bSoft)
	{
		light = shadowTemp;
	}
	else
	{
		light = 1.0f - maxSoft;
	}

	return light;
}
#endif // SHADOWS
#endif // AUX_LIGHTS
